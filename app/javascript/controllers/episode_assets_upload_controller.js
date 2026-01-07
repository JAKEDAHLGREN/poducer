import { Controller } from "@hotwired/stimulus"

// data-controller="episode-assets-upload"
// Values:
// - podcastId (Number)
// - episodeId (Number)
// Targets:
// - dropZone (drop area)
// - list (optional container to refresh/replace after upload)
export default class extends Controller {
  static targets = ["dropZone", "list"]
  static values = {
    podcastId: Number,
    episodeId: Number,
    kind: String // "assets" or "raw_audio"
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }
  highlight() {
    this.dropZoneTarget.classList.add("border-orange-400", "bg-orange-50")
  }
  unhighlight() {
    this.dropZoneTarget.classList.remove("border-orange-400", "bg-orange-50")
  }

  async handleDrop(e) {
    const dt = e.dataTransfer
    const files = Array.from(dt.files || [])
    if (!files.length) return
    await this.upload(files)
  }

  async selectFiles(e) {
    e.preventDefault()
    const input = document.createElement("input")
    input.type = "file"
    input.multiple = this.kindValue === "assets"
    input.accept = this.kindValue === "assets" ? "audio/*,video/*" : "audio/*"
    input.addEventListener("change", async (ev) => {
      const files = Array.from(ev.target.files || [])
      if (!files.length) return
      await this.upload(files)
    })
    input.click()
  }

  async upload(files) {
    const url = this.endpoint()
    const form = new FormData()
    if (this.kindValue === "assets") {
      files.forEach(f => form.append("files[]", f))
    } else {
      form.append("file", files[0])
    }
    try {
      const res = await fetch(url, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: form
      })
      if (res.ok) {
        // Simple approach: reload to reflect attachments and labels UI
        window.location.reload()
      } else {
        const data = await res.json().catch(() => ({}))
        alert(data.error || "Upload failed. Please try again.")
      }
    } catch (e) {
      alert("Upload failed. Please try again.")
    }
  }

  endpoint() {
    const base = `/podcasts/${this.podcastIdValue}/episodes/${this.episodeIdValue}/wizard`
    return this.kindValue === "assets" ? `${base}/assets` : `${base}/raw_audio`
  }
}


