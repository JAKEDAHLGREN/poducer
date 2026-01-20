import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

/**
 * Unified file upload controller for drag-and-drop file uploads
 * Works with ActiveStorage direct uploads
 * Features:
 * - Drag & drop or click to browse
 * - Inline file list with editable labels
 * - Remove files with confirmation
 * - Inline validation errors
 * - Side-by-side layout (dropzone left, file list right)
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
    console.log("File upload controller connected")
    
    // Track selected files with their labels
    this.selectedFiles = new Map() // Map<File, { label: string, error: string }>
    
    // Track existing files from server
    this.existingFilesMap = new Map()
    if (this.existingFilesValue.length > 0) {
      this.existingFilesValue.forEach(file => {
        this.existingFilesMap.set(file.id, file)
      })
    }

    // Ensure input has correct attributes
    if (this.hasInputTarget) {
      if (this.multipleValue) {
        this.inputTarget.setAttribute("multiple", "multiple")
      } else {
        this.inputTarget.removeAttribute("multiple")
      }
      console.log("Input target found:", this.inputTarget, "multiple:", this.multipleValue)
    } else {
      console.error("Input target not found!")
    }

    // Listen for form submit to extract blob signed_ids from ActiveStorage hidden inputs
    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("submit", this.handleFormSubmit.bind(this))
    }

    this.updateFileList()
    
    // Only hide instructions in single-file mode when a file is uploaded
    // In multi-file mode, always show instructions so users can add more files
    if (this.hasInstructionsTarget && !this.multipleValue && this.getTotalFileCount() > 0) {
      this.instructionsTarget.classList.add("hidden")
    }
  }

  disconnect() {
    const form = this.element.closest("form")
    if (form) {
      form.removeEventListener("submit", this.handleFormSubmit)
    }
    
    // Disconnect upload observer if it exists
    if (this.uploadObserver) {
      this.uploadObserver.disconnect()
    }
  }

  // Drag & Drop handlers
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
    console.log("Files dropped:", files.length, files)
    if (files.length > 0) {
      this.handleFiles(files)
    }
  }

  fileSelected(e) {
    const files = Array.from(e.target.files || [])
    console.log("Files selected via input:", files.length, files)
    if (files.length > 0) {
      // Filter and validate files
      const acceptedFiles = this.filterAcceptedFiles(files)
      
      if (acceptedFiles.length === 0) {
        const rejectedFiles = files.filter(f => !acceptedFiles.includes(f))
        if (rejectedFiles.length > 0 && this.acceptValue) {
          const fileTypes = rejectedFiles.map(f => f.type || "unknown").join(", ")
          alert(`The following file types are not accepted: ${fileTypes}. Please upload ${this.acceptValue} files only.`)
        }
        return
      }
      
      // For file input selection, ActiveStorage will handle direct upload automatically
      // We just need to track the files and show them in the UI
      for (const file of acceptedFiles) {
        if (!this.selectedFiles.has(file)) {
          const error = this.validateFile(file)
          this.selectedFiles.set(file, { label: "", error, uploading: false, uploaded: false })
        }
      }
      
      this.updateFileList()
      
      // Always show instructions so users can add/replace files
      if (this.hasInstructionsTarget) {
        this.instructionsTarget.classList.remove("hidden")
      }
      
      // Watch for ActiveStorage direct upload completion
      // ActiveStorage creates hidden inputs when uploads complete
      this.watchForUploadCompletion()
    }
  }

  watchForUploadCompletion() {
    // If observer already exists, don't create another one
    if (this.uploadObserver) return
    
    // Watch for hidden inputs being added by ActiveStorage
    // These are created when direct uploads complete
    const form = this.element.closest("form")
    if (!form) return

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1 && node.tagName === "INPUT" && node.type === "hidden") {
            const name = node.name
            if (name && name.includes(this.attachmentNameValue)) {
              const signedId = node.value
              console.log("Detected ActiveStorage upload completion:", signedId, "for field:", name)
              
              // Mark the most recently added file as uploaded
              // Since we can't directly match signed_id to File object, we'll mark
              // files that aren't yet uploaded
              let markedCount = 0
              this.selectedFiles.forEach((data, file) => {
                if (!data.uploaded && markedCount === 0) {
                  data.uploaded = true
                  data.blobId = signedId
                  this.selectedFiles.set(file, data)
                  markedCount++
                  console.log("Marked file as uploaded:", file.name)
                }
              })
              
              if (markedCount > 0) {
                this.updateFileList()
              }
            }
          }
        })
      })
    })

    observer.observe(form, { childList: true, subtree: true })
    
    // Store observer so we can disconnect later
    this.uploadObserver = observer
  }

  handleFiles(files) {
    console.log("handleFiles called with:", files.length, "files")
    const acceptedFiles = this.filterAcceptedFiles(files)
    console.log("Accepted files:", acceptedFiles.length)
    
    if (acceptedFiles.length === 0) {
      console.log("No accepted files after filtering")
      // Show error message to user
      const rejectedFiles = files.filter(f => !acceptedFiles.includes(f))
      if (rejectedFiles.length > 0 && this.acceptValue) {
        const fileTypes = rejectedFiles.map(f => f.type || "unknown").join(", ")
        alert(`The following file types are not accepted: ${fileTypes}. Please upload ${this.acceptValue} files only.`)
      }
      return
    }
    
    if (!this.hasInputTarget) {
      console.error("File upload controller: input target not found")
      return
    }

    // For drag & drop, use DirectUpload API
    // For file input selection, files are already in input and ActiveStorage handles them
    const isDragDrop = !this.inputTarget.files || this.inputTarget.files.length === 0
    
    if (isDragDrop) {
      // Use DirectUpload for drag & drop
      acceptedFiles.forEach(file => {
        const error = this.validateFile(file)
        this.selectedFiles.set(file, { label: "", error, uploading: false, uploaded: false })
        
        if (!error) {
          this.uploadFileDirect(file)
        }
      })
    } else {
      // Files selected via input - just track them
      for (const file of acceptedFiles) {
        if (!this.selectedFiles.has(file)) {
          const error = this.validateFile(file)
          this.selectedFiles.set(file, { label: "", error, uploading: false, uploaded: false })
        }
      }
    }

    this.updateFileList()

    // Always show instructions so users can add/replace files
    if (this.hasInstructionsTarget) {
      this.instructionsTarget.classList.remove("hidden")
    }
  }

  uploadFileDirect(file) {
    const url = this.inputTarget.dataset.directUploadUrl
    if (!url) {
      console.error("No direct upload URL found on input")
      return
    }

    const fileData = this.selectedFiles.get(file)
    fileData.uploading = true
    this.updateFileList()

    // Get attachment name from input name attribute (e.g., "episode[assets][]" -> "episode#assets")
    const inputName = this.inputTarget.name
    let attachmentName = null
    if (inputName) {
      // Extract model and attribute from name like "episode[assets][]"
      const match = inputName.match(/(\w+)\[(\w+)\]/)
      if (match) {
        attachmentName = `${match[1]}#${match[2]}`
      }
    }

    console.log("Starting DirectUpload for:", file.name, "attachment:", attachmentName)
    const upload = new DirectUpload(file, url, this, attachmentName)

    upload.create((error, blob) => {
      fileData.uploading = false
      
      if (error) {
        console.error("Direct upload error:", error)
        fileData.error = error.message || "Upload failed. Please try again."
        fileData.uploaded = false
      } else {
        console.log("Upload successful, blob:", blob)
        fileData.uploaded = true
        fileData.blobId = blob.signed_id
        fileData.error = null
        
        // Create hidden input with signed_id for form submission
        const form = this.element.closest("form")
        if (form) {
          const hiddenInput = document.createElement("input")
          hiddenInput.type = "hidden"
          hiddenInput.name = this.inputTarget.name
          hiddenInput.value = blob.signed_id
          form.appendChild(hiddenInput)
          console.log("Added hidden input with signed_id:", blob.signed_id)
        }
      }
      
      this.updateFileList()
    })
  }

  // Delegate method for DirectUpload progress tracking
  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        const percent = (event.loaded / event.total) * 100
        // Could update progress UI here if needed
        console.log("Upload progress:", percent + "%")
      }
    })
  }

  filterAcceptedFiles(files) {
    if (!this.acceptValue) return files

    const allowed = this.acceptValue.split(",").map(t => t.trim().toLowerCase())
    console.log("Filtering files. Allowed types:", allowed)
    
    return files.filter(file => {
      const type = (file.type || "").toLowerCase()
      const ext = file.name.split(".").pop()?.toLowerCase()
      
      console.log(`Checking file: ${file.name}, type: ${type}, ext: ${ext}`)
      
      // Check if file type matches (e.g., "audio/mpeg" matches "audio/*")
      const typeMatches = allowed.some(allowedType => {
        if (allowedType.includes("*")) {
          const baseType = allowedType.split("/")[0] // "audio" from "audio/*"
          return type.startsWith(baseType + "/")
        }
        return type === allowedType
      })
      
      // Check if extension matches
      const extMatches = ext && allowed.some(allowedType => {
        // Handle patterns like "audio/*" - check if ext matches common audio/video extensions
        if (allowedType.includes("*")) {
          const baseType = allowedType.split("/")[0]
          const audioExts = ["mp3", "wav", "m4a", "aac", "ogg", "flac"]
          const videoExts = ["mp4", "mov", "avi", "mkv", "webm", "m4v"]
          if (baseType === "audio") return audioExts.includes(ext)
          if (baseType === "video") return videoExts.includes(ext)
        }
        return allowedType.includes(ext)
      })
      
      const accepted = typeMatches || extMatches
      console.log(`File ${file.name}: typeMatches=${typeMatches}, extMatches=${extMatches}, accepted=${accepted}`)
      
      return accepted
    })
  }

  validateFile(file) {
    if (this.maxSizeBytesValue && file.size > this.maxSizeBytesValue) {
      const maxSizeMB = (this.maxSizeBytesValue / (1024 * 1024)).toFixed(1)
      return `File size exceeds maximum of ${maxSizeMB} MB`
    }
    return null
  }


  openFileDialog(e) {
    e.preventDefault()
    if (this.hasInputTarget) {
      this.inputTarget.click()
    }
  }

  updateLabel(e) {
    const fileId = e.target.dataset.fileId
    const label = e.target.value

    // Find in selected files
    for (const [file, data] of this.selectedFiles.entries()) {
      const fileKey = file.name
      if (fileKey === fileId) {
        data.label = label
        this.selectedFiles.set(file, data)
        return
      }
    }

    // Find in existing files
    if (this.existingFilesMap.has(fileId)) {
      const fileData = this.existingFilesMap.get(fileId)
      fileData.label = label
      this.existingFilesMap.set(fileId, fileData)
      this.updateFileList()
    }
  }

  removeFileClick(e) {
    const button = e.target.closest("button")
    if (!button) return
    
    const fileId = button.dataset.fileId
    console.log("removeFileClick called for fileId:", fileId)
    
    if (!confirm("Are you sure you want to delete this file?")) {
      return
    }

    // Try to find in selected files (pending uploads) by name
    let foundInSelected = false
    for (const [file] of this.selectedFiles.entries()) {
      if (file.name === fileId || String(file) === fileId) {
        this.selectedFiles.delete(file)
        this.removeFileFromInput(file)
        
        // For single-file mode, set remove_cover_art if it's a cover art field
        if (!this.multipleValue && this.attachmentNameValue && this.attachmentNameValue.includes("cover_art")) {
          this.setRemoveCoverArtField("1")
        }
        
        foundInSelected = true
        break
      }
    }

    if (foundInSelected) {
      this.updateFileList()
      return
    }

    // Find in existing files by ID (try both string and number)
    const fileIdNum = parseInt(fileId, 10)
    const existingFileId = this.existingFilesMap.has(fileId) ? fileId : 
                          (isNaN(fileIdNum) ? null : (this.existingFilesMap.has(fileIdNum) ? fileIdNum : null))
    
    if (existingFileId !== null) {
      console.log("Found existing file, deleting via:", this.deleteUrlValue ? "AJAX" : "remove_cover_art")
      
      if (this.deleteUrlValue) {
        // Delete via AJAX
        this.deleteExistingFile(existingFileId)
      } else {
        // No delete URL - handle via remove_cover_art field for cover art, or just remove from UI
        if (!this.multipleValue && this.attachmentNameValue && this.attachmentNameValue.includes("cover_art")) {
          this.setRemoveCoverArtField("1")
        }
        
        this.existingFilesMap.delete(existingFileId)
        this.updateFileList()
      }
    } else {
      console.warn("File not found in selectedFiles or existingFilesMap:", fileId)
    }

    // Always show instructions so users can add/replace files
    if (this.hasInstructionsTarget) {
      this.instructionsTarget.classList.remove("hidden")
    }
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

  setRemoveCoverArtField(value) {
    const form = this.element.closest("form")
    if (!form) return
    
    // Look for remove_cover_art hidden field (could be episode[remove_cover_art] or podcast[remove_cover_art])
    const field = form.querySelector('input[name*="remove_cover_art"]')
    if (field) {
      field.value = value
      console.log("Set remove_cover_art to:", value)
    }
  }

  async deleteExistingFile(fileId) {
    if (!this.deleteUrlValue) {
      // No delete URL - handle via remove_cover_art field for cover art
      if (!this.multipleValue && this.attachmentNameValue && this.attachmentNameValue.includes("cover_art")) {
        this.setRemoveCoverArtField("1")
        this.existingFilesMap.delete(fileId)
        this.updateFileList()
        return
      }
      // For other cases without delete URL, just remove from UI
      this.existingFilesMap.delete(fileId)
      this.updateFileList()
      return
    }

    try {
      const url = this.deleteUrlValue.replace(":id", String(fileId))
      console.log("Deleting file via URL:", url, "fileId:", fileId)
      const response = await fetch(url, {
        method: "DELETE",
        headers: {
          "Accept": "application/json, text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        }
      })

      if (response.ok) {
        console.log("Delete successful, removing from UI")
        this.existingFilesMap.delete(fileId)
        this.updateFileList()
        
        const contentType = response.headers.get("content-type") || ""
        if (contentType.includes("turbo-stream")) {
          const stream = await response.text()
          if (window.Turbo?.renderStreamMessage) {
            window.Turbo.renderStreamMessage(stream)
            console.log("Turbo stream processed")
          }
        } else {
          // If no turbo stream, reload to reflect changes
          console.log("No turbo stream, reloading page")
          window.location.reload()
        }
      } else {
        const errorText = await response.text().catch(() => "Unknown error")
        console.error("Delete failed:", response.status, errorText)
        alert("Failed to delete file. Please try again.")
      }
    } catch (error) {
      console.error("Delete error:", error)
      alert("Failed to delete file. Please try again.")
    }
  }

  handleFormSubmit(e) {
    // Store labels keyed by filename in a hidden input
    // Backend will match labels to files by filename after attachment
    const form = e.target
    const labels = {}
    
    // Collect labels from selected files
    this.selectedFiles.forEach((data, file) => {
      if (data.label && data.label.trim()) {
        labels[file.name] = data.label.trim()
      }
    })
    
    // Collect labels from existing files (already in form inputs, but we'll also store in JSON for consistency)
    this.existingFilesMap.forEach((fileData, id) => {
      const labelInput = form.querySelector(`input[name="${this.labelParamValue}[${id}]"]`)
      if (labelInput && labelInput.value && labelInput.value.trim()) {
        labels[fileData.filename] = labelInput.value.trim()
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

    // Update count
    const count = this.getTotalFileCount()
    const countElement = this.element.querySelector('[data-file-upload-target="fileCount"]')
    if (countElement) {
      countElement.textContent = `(${count})`
    }
  }

  createFileRow(file, id, isExisting = false, pendingData = null) {
    const row = document.createElement("div")
    row.className = "flex items-center gap-3 p-3 bg-white border border-gray-200 rounded-lg"
    
    let fileName, fileSize, currentLabel, error, isUploading
    
    if (isExisting) {
      fileName = file.filename || file.name || "Unknown"
      fileSize = file.size ? this.formatFileSize(file.size) : ""
      currentLabel = file.label || ""
      error = null
      isUploading = false
    } else {
      fileName = file.name || "Unknown"
      fileSize = this.formatFileSize(file.size)
      currentLabel = pendingData?.label || ""
      error = pendingData?.error
      isUploading = pendingData?.uploading || false
    }

    const uploadingText = isUploading ? '<div class="text-xs text-blue-600 mt-1">Uploading...</div>' : ""
    const uploadedText = (pendingData?.uploaded && !isExisting) ? '<div class="text-xs text-green-600 mt-1">Uploaded</div>' : ""

    row.innerHTML = `
      <div class="flex-1 flex items-center gap-3">
        <span class="text-lg">${this.getFileIcon(isExisting ? (file.content_type || "") : (file.type || ""))}</span>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(fileName)}</div>
          ${fileSize ? `<div class="text-xs text-gray-500">${this.escapeHtml(fileSize)}</div>` : ""}
          ${uploadingText}
          ${uploadedText}
          ${error ? `<div class="text-xs text-red-600 mt-1">${this.escapeHtml(error)}</div>` : ""}
        </div>
      </div>
      <div class="flex items-center gap-2">
        <input
          type="text"
          value="${this.escapeHtml(currentLabel)}"
          placeholder="Label (optional)"
          class="w-48 rounded-md border-gray-300 shadow-sm focus:border-orange-500 focus:ring-orange-500 text-sm"
          data-action="input->file-upload#updateLabel"
          data-file-id="${id}"
          autocomplete="off"
          ${isUploading ? "disabled" : ""}
        />
        <button
          type="button"
          class="text-red-600 hover:text-red-700 p-1 ${isUploading ? "opacity-50 cursor-not-allowed" : ""}"
          data-action="click->file-upload#removeFileClick"
          data-file-id="${id}"
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

  getTotalFileCount() {
    return this.selectedFiles.size + this.existingFilesMap.size
  }

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
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
