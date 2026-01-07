import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="media-upload"
// This Stimulus controller handles drag-and-drop file uploads and file management
// for the podcast media step in the wizard
export default class extends Controller {
  // Define the HTML elements this controller can target
  static targets = ["input", "dropZone", "fileList", "emptyState", "preview", "hint", "instructions", "fileMeta", "fileName", "fileType", "removeButton", "clearHidden"]
  // Define values that can be passed from HTML data attributes
  static values = {
    podcastId: Number,
    maxSizeBytes: Number,
    simpleMode: { type: Boolean, default: false } // when true, do not AJAX upload; assign to input (supports multi)
  }

  /**
   * Called automatically when the controller connects to the DOM
   * Sets up the drag-and-drop functionality
   */
  connect() {
    // If a preview image is already shown (server-rendered), ensure UI reflects it
    if (this.hasPreviewTarget && !this.previewTarget.classList.contains("hidden")) {
      this.hideInstructions()
      this.showFileMeta()
      this.showRemoveButton()
    } else {
      this.hideRemoveButton()
    }
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.addEventListener("click", this.removeCover.bind(this))
    }
  }

  // DnD handlers will be bound declaratively via data-action on the drop zone

  /**
   * Prevents the browser's default behavior for drag events
   * Without this, the browser might try to navigate to the file or open it
   * @param {Event} e - The drag event
   */
  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  /**
   * Adds visual styling to show the drop zone is active
   * Changes border and background color to orange when files are dragged over
   * @param {Event} e - The drag event
   */
  highlight(e) {
    this.dropZoneTarget.classList.add('border-orange-400', 'bg-orange-50')
  }

  /**
   * Removes visual styling when drag ends
   * Returns the drop zone to its normal appearance
   * @param {Event} e - The drag event
   */
  unhighlight(e) {
    this.dropZoneTarget.classList.remove('border-orange-400', 'bg-orange-50')
  }

  /**
   * Handles files that are dropped onto the drop zone
   * Extracts files from the drop event and processes them
   * @param {Event} e - The drop event containing the files
   */
  handleDrop(e) {
    const dt = e.dataTransfer
    const files = dt.files
    this.handleFiles(files, { triggerChange: true })
  }

  /**
   * Processes multiple files for upload
   * Iterates through each file and uploads them one by one
   * @param {FileList} files - The files to be uploaded
   */
  async handleFiles(files, { triggerChange = false } = {}) {
    if (!files || files.length === 0) return

    if (this.isSingleImageMode()) {
      const file = files[0]
      if (!this.isAcceptedType(file)) {
        alert("Please choose a PNG, JPG, or WEBP image.")
        return
      }
      // TODO: Decide what the max size should be for the cover image and uncomment this
      // if (this.maxSizeBytesValue && file.size > this.maxSizeBytesValue) {
      //   alert("Image is too large. Max size is 5 MB.")
      //   return
      // }
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(file)
      this.inputTarget.files = dataTransfer.files
      this.updatePreview(file)
      if (triggerChange) {
        this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
      }
    } else {
      // Multi-file mode
      const useSimple = this.simpleModeValue || (!this.hasPodcastIdValue && this.hasFileListTarget)
      if (useSimple) {
        const dataTransfer = new DataTransfer()
        Array.from(files).forEach(f => {
          if (this.isAcceptedType(f)) dataTransfer.items.add(f)
        })
        this.inputTarget.files = dataTransfer.files
        this.updateFileList(this.inputTarget.files)
        if (triggerChange) {
          this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
        }
      } else {
        // Upload each file individually via AJAX (podcast flow)
        for (let file of files) {
          await this.uploadFile(file)
        }
      }
    }
  }

  /**
   * Handles file selection from the file input element
   * This is triggered when users click "Select Files" and choose files
   * @param {Event} event - The change event from the file input
   */
  fileSelected(event) {
    const files = event.target.files
    const useSimple = this.simpleModeValue || (!this.hasPodcastIdValue && this.hasFileListTarget)
    if (useSimple && !this.isSingleImageMode()) {
      this.updateFileList(files)
      return
    }
    this.handleFiles(files, { triggerChange: false })
    if (!this.isSingleImageMode() && !this.simpleModeValue) {
      event.target.value = ''
    }
  }

  /**
   * Uploads a single file to the server via AJAX
   * Creates a FormData object and sends it to the Rails controller
   * @param {File} file - The file to upload
   */
  async uploadFile(file) {
    const formData = new FormData()
    let url
    // Episode immediate uploads (endpoint provided on dropZone)
    const endpoint = this.hasDropZoneTarget ? (this.dropZoneTarget.dataset.endpoint || "") : ""
    const kind = this.hasDropZoneTarget ? (this.dropZoneTarget.dataset.kind || "") : ""
    if (endpoint) {
      if (kind === "assets") {
        formData.append('files[]', file)
      } else {
        formData.append('file', file)
      }
      url = endpoint
    } else {
      // Podcast cover media (existing behavior)
      formData.append('podcast[media][]', file)
      url = `/podcasts/${this.podcastIdValue}/wizard/media`
    }

    try {
      const response = await fetch(url, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        window.location.reload()
      } else {
        alert('Upload failed. Please try again.')
      }
    } catch (error) {
      console.error("Upload error:", error)
      alert('Upload failed. Please try again.')
    }
  }

  isSingleImageMode() {
    // If there is no fileList target on the page, treat as single-image mode
    return !this.hasFileListTarget
  }

  /**
   * Removes an existing file from the server
   * This is called when users click the 'x' button next to uploaded files
   * @param {Event} event - The click event from the delete button
   */
  async removeExistingFile(event) {
    event.preventDefault()

    // Get the file ID from the button's data attribute
    const fileId = event.currentTarget.dataset.fileId
    console.log("Attempting to delete file with ID:", fileId)

    if (!fileId) { console.error("No file ID found"); return }

    // Ask for confirmation before deleting
    if (!confirm('Are you sure you want to delete this file?')) {
      return
    }

    try {
      // Send DELETE request to Rails controller
      const response = await fetch(`/podcasts/${this.podcastIdValue}/media/${fileId}`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          // Include CSRF token for Rails security
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        console.log("File deleted successfully, refreshing page...")
        // Refresh page to show updated file list without the deleted file
        window.location.reload()
      } else {
        alert('Failed to delete file. Please try again.')
      }
    } catch (error) {
      console.error("Delete error:", error)
      alert('Failed to delete file. Please try again.')
    }
  }

  async deleteByUrl(url) {
    if (!confirm('Are you sure you want to delete this file?')) return
    try {
      const response = await fetch(url, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      if (response.ok) {
        window.location.reload()
      } else {
        alert('Failed to delete file. Please try again.')
      }
    } catch (e) {
      alert('Failed to delete file. Please try again.')
    }
  }

  clear(event) { this.removeCover(event) }

  /**
   * Updates the visibility of the "no files" message
   * Shows/hides the empty state based on whether files are present
   * Currently not used but kept for potential future enhancements
   */
  updateEmptyState() {
    if (!this.hasEmptyStateTarget) return

    const hasFiles = this.hasFileListTarget && this.fileListTarget.children.length > 0

    if (hasFiles) {
      this.emptyStateTarget.classList.add('hidden')
    } else {
      this.emptyStateTarget.classList.remove('hidden')
    }
  }

  updateFileList(fileList) {
    if (!this.hasFileListTarget) return
    this.fileListTarget.innerHTML = ''
    Array.from(fileList || []).forEach(file => {
      const row = document.createElement('div')
      row.className = 'flex items-center justify-between p-2 bg-white rounded border'
      row.innerHTML = `
        <div class="flex items-center gap-2">
          <span class="text-sm">${this.getFileIcon(file.type)}</span>
          <span class="text-sm text-gray-700">${file.name}</span>
          <span class="text-xs text-gray-500">${this.formatFileSize(file.size)}</span>
        </div>
      `
      this.fileListTarget.appendChild(row)
    })
  }
  /**
   * Formats file size in bytes to human-readable format
   * Converts bytes to KB, MB, GB as appropriate
   * @param {number} bytes - The file size in bytes
   * @returns {string} - Formatted file size (e.g., "1.5 MB")
   */
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  /**
   * Returns an appropriate emoji icon based on file type
   * Helps users quickly identify different types of files
   * @param {string} contentType - The MIME type of the file
   * @returns {string} - An emoji representing the file type
   */
  getFileIcon(contentType) {
    if (contentType.startsWith('image/')) return '🖼️'  // Images
    if (contentType.startsWith('video/')) return '🎥'  // Videos
    if (contentType.startsWith('audio/')) return '🎵'  // Audio files
    if (contentType.includes('pdf')) return '📄'       // PDF documents
    if (contentType.includes('text/')) return '📝'     // Text files
    return '📁'  // Default for unknown file types
  }

  /**
   * Opens the file dialog when the "Select Files" button is clicked
   * This triggers the hidden file input element
   * @param {Event} event - The click event from the button
   */
  openFileDialog(event) {
    event.preventDefault()
    if (this.hasInputTarget) {
      this.inputTarget.click()
    }
  }

  isAcceptedType(file) {
    const acceptAttr = this.hasInputTarget ? this.inputTarget.accept : ""
    if (!acceptAttr) return true
    const allowed = acceptAttr.split(",").map(t => t.trim().toLowerCase())
    const type = file.type.toLowerCase()
    const ext = file.name.split(".").pop()?.toLowerCase()
    return allowed.includes(type) || (ext && allowed.some(a => a.includes(ext)))
  }

  updatePreview(file) {
    if (!this.hasPreviewTarget) return
    const reader = new FileReader()
    reader.onload = e => {
      this.previewTarget.src = e.target.result
      this.previewTarget.classList.remove("hidden")
      this.previewTarget.dataset.existing = "false"
    }
    reader.readAsDataURL(file)
    if (this.hasFileNameTarget) this.fileNameTarget.textContent = file.name || "Selected image"
    if (this.hasFileTypeTarget) this.fileTypeTarget.textContent = file.type || "image/*"
    this.hideInstructions()
    this.showFileMeta()
    this.showRemoveButton()
  }

  hideInstructions() {
    if (this.hasInstructionsTarget) this.instructionsTarget.classList.add("hidden")
  }

  showFileMeta() {
    if (this.hasFileMetaTarget) this.fileMetaTarget.classList.remove("hidden")
  }

  async removeCover(event) {
    event.preventDefault()
    // Reset UI
    if (this.hasPreviewTarget) {
      this.previewTarget.src = ""
      this.previewTarget.classList.add("hidden")
      this.previewTarget.dataset.existing = "false"
    }
    if (this.hasFileMetaTarget) this.fileMetaTarget.classList.add("hidden")
    if (this.hasFileNameTarget) this.fileNameTarget.textContent = ""
    if (this.hasFileTypeTarget) this.fileTypeTarget.textContent = ""
    if (this.hasInstructionsTarget) this.instructionsTarget.classList.remove("hidden")
    if (this.hasInputTarget) this.inputTarget.value = ""
    if (this.hasClearHiddenTarget) this.clearHiddenTarget.value = "1"
    this.hideRemoveButton()
  }

  csrfToken() {
    const el = document.querySelector('meta[name="csrf-token"]')
    return el ? el.content : ""
  }

  showRemoveButton() {
    if (this.hasRemoveButtonTarget) this.removeButtonTarget.classList.remove("hidden")
  }

  hideRemoveButton() {
    if (this.hasRemoveButtonTarget) this.removeButtonTarget.classList.add("hidden")
  }
}
