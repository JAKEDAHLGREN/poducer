import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="media-upload"
// This Stimulus controller handles drag-and-drop file uploads and file management
// for the podcast media step in the wizard
export default class extends Controller {
  // Define the HTML elements this controller can target
  static targets = ["input", "dropZone", "fileList", "emptyState"]
  // Define values that can be passed from HTML data attributes
  static values = { podcastId: Number }

  /**
   * Called automatically when the controller connects to the DOM
   * Sets up the drag-and-drop functionality
   */
  connect() {
    console.log("Media upload controller connected successfully!")
    console.log("Podcast ID:", this.podcastIdValue)
    this.setupDragAndDrop()
  }

  /**
   * Sets up all the drag-and-drop event listeners
   * Handles visual feedback and file dropping functionality
   */
  setupDragAndDrop() {
    // Check if the drop zone element exists in the DOM
    if (!this.hasDropZoneTarget) {
      console.error("Drop zone target not found!")
      return
    }

    // Prevent the browser's default drag behaviors (like opening files)
    // We need to prevent these on both the drop zone and the document body
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      this.dropZoneTarget.addEventListener(eventName, this.preventDefaults.bind(this), false)
      document.body.addEventListener(eventName, this.preventDefaults.bind(this), false)
    })

    // Add visual feedback when files are dragged over the drop zone
    // These events make the drop zone highlight when files are dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
      this.dropZoneTarget.addEventListener(eventName, this.highlight.bind(this), false)
    })

    // Remove visual feedback when files are dragged away or dropped
    ['dragleave', 'drop'].forEach(eventName => {
      this.dropZoneTarget.addEventListener(eventName, this.unhighlight.bind(this), false)
    })

    // Handle the actual file drop event
    this.dropZoneTarget.addEventListener('drop', this.handleDrop.bind(this), false)
  }

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
    const dt = e.dataTransfer  // Get the data transfer object
    const files = dt.files     // Extract the files from it
    this.handleFiles(files)    // Process the files
  }

  /**
   * Processes multiple files for upload
   * Iterates through each file and uploads them one by one
   * @param {FileList} files - The files to be uploaded
   */
  async handleFiles(files) {
    if (!files || files.length === 0) return

    // Upload each file individually
    for (let file of files) {
      await this.uploadFile(file)
    }
  }

  /**
   * Handles file selection from the file input element
   * This is triggered when users click "Select Files" and choose files
   * @param {Event} event - The change event from the file input
   */
  fileSelected(event) {
    this.handleFiles(event.target.files)
    // Clear the input so the same file can be selected again if needed
    event.target.value = ''
  }

  /**
   * Uploads a single file to the server via AJAX
   * Creates a FormData object and sends it to the Rails controller
   * @param {File} file - The file to upload
   */
  async uploadFile(file) {
    console.log("Uploading file:", file.name)

    // Create FormData object to send the file
    // This mimics a form submission with the file
    const formData = new FormData()
    formData.append('podcast[media][]', file)  // Rails expects this format

    try {
      // Send PATCH request to the Rails controller
      const response = await fetch(`/podcasts/${this.podcastIdValue}/wizard/media`, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'application/json',
          // Include CSRF token for Rails security
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const result = await response.json()
        console.log("Upload successful:", result)
        // Refresh the page to show the newly uploaded file
        // This ensures the server-side file list is displayed
        window.location.reload()
      } else {
        console.error("Upload failed:", response.status, response.statusText)
        alert('Upload failed. Please try again.')
      }
    } catch (error) {
      console.error("Upload error:", error)
      alert('Upload failed. Please try again.')
    }
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

    if (!fileId) {
      console.error("No file ID found")
      return
    }

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
}
