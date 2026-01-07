import { Controller } from "@hotwired/stimulus"

// data-controller="episode-upload"
// Supports both single-file and multiple-file drag-and-drop, without AJAX.
// It assigns dropped files to the hidden file input and updates a simple list UI if provided.
export default class extends Controller {
  static targets = ["input", "dropZone", "fileList", "instructions"]
  static values = {
    multiple: { type: Boolean, default: false },
    accept: String
  }

  connect() {
    // no-op
  }

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
    const dt = e.dataTransfer
    const files = Array.from(dt.files || [])
    if (!files.length) return

    const filtered = this.filterAccepted(files)
    this.assignFiles(filtered)
    this.renderList(filtered)
  }

  fileSelected(event) {
    const files = Array.from(event.target.files || [])
    this.renderList(this.filterAccepted(files))
  }

  filterAccepted(files) {
    if (!this.acceptValue) return files
    const allowed = this.acceptValue.split(",").map(s => s.trim().toLowerCase())
    return files.filter(file => {
      const type = (file.type || "").toLowerCase()
      const ext = file.name.split(".").pop()?.toLowerCase()
      return allowed.includes(type) || (ext && allowed.some(a => a.includes(ext)))
    })
  }

  assignFiles(files) {
    if (!this.hasInputTarget || files.length === 0) return
    const dt = new DataTransfer()
    if (this.multipleValue) {
      files.forEach(f => dt.items.add(f))
    } else {
      dt.items.add(files[0])
    }
    this.inputTarget.files = dt.files
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    if (this.hasInstructionsTarget) this.instructionsTarget.classList.add("hidden")
  }

  renderList(files) {
    if (!this.hasFileListTarget) return
    this.fileListTarget.innerHTML = ""
    files.forEach(file => {
      const li = document.createElement("div")
      li.className = "flex items-center justify-between p-2 bg-white border rounded"
      li.innerHTML = `
        <div class="flex items-center gap-2">
          <span class="text-sm text-gray-700">${file.name}</span>
          <span class="text-xs text-gray-500">${(file.type || "").split("/")[0] || "file"}</span>
        </div>
      `
      this.fileListTarget.appendChild(li)
    })
  }
}


