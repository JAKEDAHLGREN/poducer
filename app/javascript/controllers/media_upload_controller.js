import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "previews", "noFilesMessage", "existingFiles"]
  static values = { podcastId: Number }

  connect() {
    this.selectedFiles = []
    // Check if there are already files in the input (from previous navigation)
    if (this.inputTarget.files && this.inputTarget.files.length > 0) {
      this.selectedFiles = Array.from(this.inputTarget.files)
      this.renderFilePreviews()
    }
    this.updateNoFilesMessage()
  }

  async fileSelected(event) {
    const newFiles = Array.from(event.target.files)

    // Add new files to existing selection
    newFiles.forEach(file => {
      // Check if file is already selected (by name and size)
      const isDuplicate = this.selectedFiles.some(existingFile =>
        existingFile.name === file.name && existingFile.size === file.size
      )

      if (!isDuplicate) {
        this.selectedFiles.push(file)
      }
    })

    this.updateFileInput()
    this.renderFilePreviews()

    // Auto-save the files to the database
    await this.saveFilesToDatabase()

    // Clear the input so the same file can be selected again if removed
    setTimeout(() => {
      event.target.value = ''
    }, 100)
  }

  async saveFilesToDatabase() {
    const formData = new FormData()
    formData.append('authenticity_token', document.querySelector('meta[name="csrf-token"]').content)

    this.selectedFiles.forEach(file => {
      formData.append('podcast[media][]', file)
    })

    try {
      const response = await fetch(`/podcasts/${this.podcastIdValue}/wizard/media`, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        // Files saved successfully, refresh the page to show them as "saved"
        window.location.reload()
      }
    } catch (error) {
      console.error('Error saving files:', error)
    }
  }

  removeFile(event) {
    const index = parseInt(event.currentTarget.dataset.fileIndex)
    this.selectedFiles.splice(index, 1)
    this.updateFileInput()
    this.renderFilePreviews()
  }

  updateFileInput() {
    // Create a new DataTransfer to hold the remaining files
    const dt = new DataTransfer()
    this.selectedFiles.forEach(file => {
      dt.items.add(file)
    })
    this.inputTarget.files = dt.files
  }

  renderFilePreviews() {
    this.previewsTarget.innerHTML = ''

    this.selectedFiles.forEach((file, index) => {
      const filePreview = this.createFilePreview(file, index)
      this.previewsTarget.appendChild(filePreview)
    })

    this.updateNoFilesMessage()
  }

  createFilePreview(file, index) {
    const fileDiv = document.createElement('div')
    fileDiv.className = 'flex items-center justify-between p-3 bg-orange-50 border border-orange-200 rounded-lg'

    fileDiv.innerHTML = `
      <div class="flex items-center">
        <div class="h-5 w-5 bg-orange-500 rounded mr-2 flex items-center justify-center text-white text-xs font-bold">
          📄
        </div>
        <div>
          <span class="text-sm text-gray-700 font-medium">${file.name}</span>
          <div class="text-xs text-gray-500">${this.formatFileSize(file.size)} - Saving...</div>
        </div>
      </div>
      <button type="button" class="text-red-500 hover:text-red-700 p-2 font-bold text-lg leading-none" data-action="click->media-upload#removeFile" data-file-index="${index}">
        ×
      </button>
    `

    return fileDiv
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  updateNoFilesMessage() {
    const hasExistingFiles = this.hasExistingFilesTarget && this.existingFilesTarget.children.length > 0
    const hasNewFiles = this.selectedFiles.length > 0

    if (hasExistingFiles || hasNewFiles) {
      this.noFilesMessageTarget.classList.add('hidden')
    } else {
      this.noFilesMessageTarget.classList.remove('hidden')
    }
  }
}
