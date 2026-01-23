import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

/**
 * Unified file upload controller for drag-and-drop file uploads
 * Works with ActiveStorage direct uploads
 *
 * Features:
 * - Drag & drop or click to browse
 * - Single or multiple file uploads
 * - Inline file list with editable labels
 * - Remove files with confirmation
 * - File size and type validation
 * - Progress tracking for uploads
 * - Side-by-side layout (dropzone left, file list right)
 *
 * Usage in ERB:
 *   <%= render "shared/file_upload",
 *         form: f,
 *         attachment_name: :assets,
 *         multiple: true,
 *         accept: "audio/*,video/*",
 *         max_size_mb: 500,
 *         existing_files: @episode.assets.attachments,
 *         delete_url: some_path(id: ":id"),
 *         section_label: "Upload Assets" %>
 */
export default class extends Controller {
  static targets = [
    "dropZone",
    "input",
    "fileList",
    "instructions"
  ]

  static values = {
    multiple: { type: Boolean, default: false },
    accept: String,
    maxSizeBytes: Number,
    attachmentName: { type: String, default: "files" },
    labelParam: { type: String, default: "asset_labels" },
    deleteUrl: String,
    existingFiles: { type: Array, default: [] }
  }

  connect() {
    // Track selected files with their labels and upload status
    // Map<File, { label: string, error: string, uploading: boolean, uploaded: boolean, blobId: string }>
    this.selectedFiles = new Map()

    // Track existing files from server
    this.existingFilesMap = new Map()
    if (this.existingFilesValue.length > 0) {
      this.existingFilesValue.forEach(file => {
        this.existingFilesMap.set(file.id, file)
      })
    }

    // Ensure input has correct multiple attribute
    if (this.hasInputTarget) {
      if (this.multipleValue) {
        this.inputTarget.setAttribute("multiple", "multiple")
      } else {
        this.inputTarget.removeAttribute("multiple")
      }
    }

    // Listen for form submit to collect labels
    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("submit", this.handleFormSubmit.bind(this))
    }

    this.updateFileList()
    this.updateInstructionsVisibility()
  }

  disconnect() {
    const form = this.element.closest("form")
    if (form) {
      form.removeEventListener("submit", this.handleFormSubmit)
    }
  }

  // ==================
  // Drag & Drop Events
  // ==================

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight() {
    if (this.hasDropZoneTarget) {
      this.dropZoneTarget.classList.add("border-orange-400", "bg-orange-50")
    }
  }

  unhighlight() {
    if (this.hasDropZoneTarget) {
      this.dropZoneTarget.classList.remove("border-orange-400", "bg-orange-50")
    }
  }

  handleDrop(e) {
    this.preventDefaults(e)
    this.unhighlight()

    const files = Array.from(e.dataTransfer.files || [])
    if (files.length > 0) {
      this.handleFiles(files, { fromDrop: true })
    }
  }

  // ==================
  // File Selection
  // ==================

  fileSelected(e) {
    const files = Array.from(e.target.files || [])
    if (files.length > 0) {
      this.handleFiles(files, { fromDrop: false })
      // Clear the file input value
      e.target.value = ""
    }
  }

  openFileDialog(e) {
    e.preventDefault()
    if (this.hasInputTarget) {
      this.inputTarget.click()
    }
  }

  // ==================
  // File Processing
  // ==================

  handleFiles(files, { fromDrop = false } = {}) {
    const acceptedFiles = this.filterAcceptedFiles(files)

    if (acceptedFiles.length === 0) {
      if (files.length > 0 && this.acceptValue) {
        const rejectedTypes = files.map(f => f.type || f.name.split('.').pop()).join(", ")
        alert(`File type not accepted: ${rejectedTypes}. Please upload ${this.acceptValue} files.`)
      }
      return
    }

    // For single file mode, clear existing selections and hidden inputs
    if (!this.multipleValue) {
      this.clearExistingUploads()
      this.selectedFiles.clear()
    }

    // Process each file
    acceptedFiles.forEach(file => {
      // Skip if already selected (by name and size)
      const isDuplicate = this.isDuplicateFile(file)
      if (isDuplicate) return

      const error = this.validateFile(file)
      this.selectedFiles.set(file, {
        label: "",
        error,
        uploading: false,
        uploaded: false,
        blobId: null
      })

      // Always use DirectUpload for consistent tracking
      // This works for both drag & drop and file input selections
      if (!error) {
        this.uploadFileDirect(file)
      }
    })

    this.updateFileList()
    this.updateInstructionsVisibility()
  }

  clearExistingUploads() {
    // Remove any existing hidden inputs for this attachment
    const form = this.element.closest("form")
    if (!form) return

    const inputName = this.hasInputTarget ? this.inputTarget.name : null
    if (!inputName) return

    form.querySelectorAll(`input[type="hidden"][name="${inputName}"]`).forEach(input => {
      input.remove()
    })
  }

  isDuplicateFile(file) {
    for (const [existingFile] of this.selectedFiles.entries()) {
      if (existingFile.name === file.name &&
          existingFile.size === file.size &&
          existingFile.lastModified === file.lastModified) {
        return true
      }
    }
    return false
  }

  filterAcceptedFiles(files) {
    if (!this.acceptValue) return files

    const allowed = this.acceptValue.split(",").map(t => t.trim().toLowerCase())

    return files.filter(file => {
      const type = (file.type || "").toLowerCase()
      const ext = file.name.split(".").pop()?.toLowerCase()

      // Check MIME type match (e.g., "audio/mpeg" matches "audio/*")
      const typeMatches = allowed.some(allowedType => {
        if (allowedType.includes("*")) {
          const baseType = allowedType.split("/")[0]
          return type.startsWith(baseType + "/")
        }
        // Exact MIME type match (e.g., "audio/wav", "audio/x-wav")
        return type === allowedType
      })

      // Check extension match (handles both ".wav" patterns and MIME wildcards)
      const extMatches = ext && allowed.some(allowedType => {
        // Handle file extension patterns like ".wav", ".mp3"
        if (allowedType.startsWith(".")) {
          return allowedType === `.${ext}`
        }
        // Handle MIME type wildcards like "audio/*"
        if (allowedType.includes("*")) {
          const baseType = allowedType.split("/")[0]
          const audioExts = ["mp3", "wav", "m4a", "aac", "ogg", "flac", "wma", "aiff", "aif"]
          const videoExts = ["mp4", "mov", "avi", "mkv", "webm", "m4v", "wmv", "flv"]
          const imageExts = ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff"]
          if (baseType === "audio") return audioExts.includes(ext)
          if (baseType === "video") return videoExts.includes(ext)
          if (baseType === "image") return imageExts.includes(ext)
        }
        return false
      })

      return typeMatches || extMatches
    })
  }

  validateFile(file) {
    if (this.maxSizeBytesValue && file.size > this.maxSizeBytesValue) {
      const maxSizeMB = (this.maxSizeBytesValue / (1024 * 1024)).toFixed(0)
      return `File too large. Maximum size is ${maxSizeMB} MB.`
    }
    return null
  }

  // ==================
  // Direct Upload
  // ==================

  uploadFileDirect(file) {
    if (!this.hasInputTarget) return

    const url = this.inputTarget.dataset.directUploadUrl
    if (!url) return

    const fileData = this.selectedFiles.get(file)
    if (!fileData) return

    fileData.uploading = true
    this.updateFileList()

    const upload = new DirectUpload(file, url, this)

    upload.create((error, blob) => {
      fileData.uploading = false

      if (error) {
        fileData.error = error.message || "Upload failed. Please try again."
        fileData.uploaded = false
      } else {
        fileData.uploaded = true
        fileData.blobId = blob.signed_id
        fileData.error = null

        // Create hidden input with signed_id for form submission
        this.addHiddenInput(blob.signed_id)
      }

      this.updateFileList()
    })
  }

  // DirectUpload delegate method for progress tracking
  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        const percent = (event.loaded / event.total) * 100
        // Progress tracking - could be enhanced with UI feedback
      }
    })
  }

  addHiddenInput(signedId) {
    const form = this.element.closest("form")
    if (!form) return

    const input = document.createElement("input")
    input.type = "hidden"
    input.name = this.inputTarget.name
    input.value = signedId
    input.dataset.signedId = signedId
    form.appendChild(input)
  }


  // ==================
  // File Removal
  // ==================

  removeFileClick(e) {
    const button = e.target.closest("button")
    if (!button) return

    const fileId = button.dataset.fileId

    if (!confirm("Are you sure you want to remove this file?")) {
      return
    }

    // Try to find in selected files (pending uploads)
    for (const [file] of this.selectedFiles.entries()) {
      if (file.name === fileId) {
        const fileData = this.selectedFiles.get(file)

        // Remove hidden input if file was uploaded
        if (fileData?.blobId) {
          const form = this.element.closest("form")
          const hiddenInput = form?.querySelector(`input[data-signed-id="${fileData.blobId}"]`)
          hiddenInput?.remove()
        }

        this.selectedFiles.delete(file)
        this.removeFileFromInput(file)
        this.handleSingleFileCoverArtRemoval()
        this.updateFileList()
        this.updateInstructionsVisibility()
        return
      }
    }

    // Try to find in existing files
    const existingFileId = this.findExistingFileId(fileId)
    if (existingFileId !== null) {
      if (this.deleteUrlValue) {
        this.deleteExistingFile(existingFileId)
      } else {
        // No delete URL - handle via form field for cover art
        this.handleSingleFileCoverArtRemoval()
        this.existingFilesMap.delete(existingFileId)
        this.updateFileList()
        this.updateInstructionsVisibility()
      }
    }
  }

  findExistingFileId(fileId) {
    // Try string match first, then number
    if (this.existingFilesMap.has(fileId)) return fileId

    const numId = parseInt(fileId, 10)
    if (!isNaN(numId) && this.existingFilesMap.has(numId)) return numId

    return null
  }

  removeFileFromInput(fileToRemove) {
    if (!this.hasInputTarget) return

    const dt = new DataTransfer()
    const currentFiles = Array.from(this.inputTarget.files || [])

    currentFiles.forEach(file => {
      if (file !== fileToRemove && file.name !== fileToRemove.name) {
        dt.items.add(file)
      }
    })

    this.inputTarget.files = dt.files
  }

  handleSingleFileCoverArtRemoval() {
    if (this.multipleValue) return
    if (!this.attachmentNameValue?.includes("cover_art")) return

    const form = this.element.closest("form")
    if (!form) return

    const field = form.querySelector('input[name*="remove_cover_art"]')
    if (field) {
      field.value = "1"
    }
  }

  async deleteExistingFile(fileId) {
    if (!this.deleteUrlValue) return

    try {
      const url = this.deleteUrlValue.replace(":id", String(fileId))
      const response = await fetch(url, {
        method: "DELETE",
        headers: {
          "Accept": "application/json, text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken()
        }
      })

      if (response.ok) {
        this.existingFilesMap.delete(fileId)
        this.updateFileList()
        this.updateInstructionsVisibility()

        // Handle Turbo Stream response if present
        const contentType = response.headers.get("content-type") || ""
        if (contentType.includes("turbo-stream")) {
          const stream = await response.text()
          if (window.Turbo?.renderStreamMessage) {
            window.Turbo.renderStreamMessage(stream)
          }
        }
      } else {
        alert("Failed to delete file. Please try again.")
      }
    } catch (error) {
      alert("Failed to delete file. Please try again.")
    }
  }

  // ==================
  // Labels
  // ==================

  updateLabel(e) {
    const fileId = e.target.dataset.fileId
    const label = e.target.value

    // Check selected files
    for (const [file, data] of this.selectedFiles.entries()) {
      if (file.name === fileId) {
        data.label = label
        return
      }
    }

    // Check existing files
    const existingFileId = this.findExistingFileId(fileId)
    if (existingFileId !== null) {
      const fileData = this.existingFilesMap.get(existingFileId)
      if (fileData) {
        fileData.label = label
      }
    }
  }

  handleFormSubmit(e) {
    const form = e.target
    const labels = {}

    // Collect labels from selected files
    this.selectedFiles.forEach((data, file) => {
      if (data.label?.trim()) {
        labels[file.name] = data.label.trim()
      }
    })

    // Store labels JSON in hidden input
    if (Object.keys(labels).length > 0) {
      let labelsInput = form.querySelector(`input[name="${this.labelParamValue}_json"]`)
      if (!labelsInput) {
        labelsInput = document.createElement("input")
        labelsInput.type = "hidden"
        labelsInput.name = `${this.labelParamValue}_json`
        form.appendChild(labelsInput)
      }
      labelsInput.value = JSON.stringify(labels)
    }
  }

  // ==================
  // UI Updates
  // ==================

  updateFileList() {
    if (!this.hasFileListTarget) return

    this.fileListTarget.innerHTML = ""

    // Render existing files
    this.existingFilesMap.forEach((fileData, id) => {
      const row = this.createFileRow(fileData, id, true)
      this.fileListTarget.appendChild(row)
    })

    // Render selected files
    this.selectedFiles.forEach((data, file) => {
      const row = this.createFileRow(file, file.name, false, data)
      this.fileListTarget.appendChild(row)
    })

    // Show empty state if no files
    if (this.getTotalFileCount() === 0) {
      const emptyState = document.createElement("p")
      emptyState.className = "text-sm text-gray-500 text-center py-4"
      emptyState.textContent = "No files uploaded yet."
      this.fileListTarget.appendChild(emptyState)
    }

    // Update count display
    const countElement = this.element.querySelector('[data-file-upload-target="fileCount"]')
    if (countElement) {
      countElement.textContent = `(${this.getTotalFileCount()})`
    }
  }

  createFileRow(file, id, isExisting = false, pendingData = null) {
    const row = document.createElement("div")
    row.className = "flex items-center gap-3 p-3 bg-white border border-gray-200 rounded-lg"

    let fileName, fileSize, currentLabel, error, isUploading, isUploaded

    if (isExisting) {
      fileName = file.filename || file.name || "Unknown"
      fileSize = file.size ? this.formatFileSize(file.size) : ""
      currentLabel = file.label || ""
      error = null
      isUploading = false
      isUploaded = true
    } else {
      fileName = file.name || "Unknown"
      fileSize = this.formatFileSize(file.size)
      currentLabel = pendingData?.label || ""
      error = pendingData?.error
      isUploading = pendingData?.uploading || false
      isUploaded = pendingData?.uploaded || false
    }

    const contentType = isExisting ? (file.content_type || "") : (file.type || "")
    const statusHtml = this.getStatusHtml(isUploading, isUploaded, error)

    row.innerHTML = `
      <div class="flex-1 flex items-center gap-3 min-w-0">
        <span class="text-lg flex-shrink-0">${this.getFileIcon(contentType)}</span>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(fileName)}</div>
          ${fileSize ? `<div class="text-xs text-gray-500">${this.escapeHtml(fileSize)}</div>` : ""}
          ${statusHtml}
        </div>
      </div>
      <div class="flex items-center gap-2 flex-shrink-0">
        <input
          type="text"
          value="${this.escapeHtml(currentLabel)}"
          placeholder="Label (optional)"
          class="w-48 rounded-md border-gray-300 shadow-sm focus:border-orange-500 focus:ring-orange-500 text-sm"
          data-action="input->file-upload#updateLabel"
          data-file-id="${this.escapeHtml(String(id))}"
          autocomplete="off"
          ${isUploading ? "disabled" : ""}
        />
        <button
          type="button"
          class="text-red-600 hover:text-red-700 p-1 ${isUploading ? "opacity-50 cursor-not-allowed" : ""}"
          data-action="click->file-upload#removeFileClick"
          data-file-id="${this.escapeHtml(String(id))}"
          title="Remove file"
          ${isUploading ? "disabled" : ""}
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    `

    return row
  }

  getStatusHtml(isUploading, isUploaded, error) {
    if (error) {
      return `<div class="text-xs text-red-600 mt-1">${this.escapeHtml(error)}</div>`
    }
    if (isUploading) {
      return `<div class="text-xs text-blue-600 mt-1">Uploading...</div>`
    }
    if (isUploaded) {
      return `<div class="text-xs text-green-600 mt-1">Uploaded</div>`
    }
    return ""
  }

  updateInstructionsVisibility() {
    if (!this.hasInstructionsTarget) return

    // Always show instructions so users can add more files
    this.instructionsTarget.classList.remove("hidden")
  }

  getTotalFileCount() {
    return this.selectedFiles.size + this.existingFilesMap.size
  }

  // ==================
  // Utilities
  // ==================

  getFileIcon(contentType) {
    if (!contentType) return "📁"
    if (contentType.startsWith("image/")) return "🖼️"
    if (contentType.startsWith("video/")) return "🎥"
    if (contentType.startsWith("audio/")) return "🎵"
    if (contentType.includes("pdf")) return "📄"
    if (contentType.includes("text/")) return "📝"
    return "📁"
  }

  formatFileSize(bytes) {
    if (!bytes || bytes === 0) return ""
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }

  escapeHtml(text) {
    if (text === null || text === undefined) return ""
    const div = document.createElement("div")
    div.textContent = String(text)
    return div.innerHTML
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta?.content || ""
  }
}
