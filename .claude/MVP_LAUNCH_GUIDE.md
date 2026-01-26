# Poducer MVP Launch Guide

A comprehensive checklist and guide for launching the Poducer podcast production platform.

---

## Table of Contents

1. [Application Overview](#application-overview)
2. [File Storage (AWS S3 Setup)](#file-storage-aws-s3-setup)
3. [Hosting Recommendations](#hosting-recommendations)
4. [Backend Work Required](#backend-work-required)
5. [Reusable Dropzone Component](#reusable-dropzone-component)
6. [Edge Cases & Issues](#edge-cases--issues)
7. [Pre-Launch Checklist](#pre-launch-checklist)
8. [Post-Launch Monitoring](#post-launch-monitoring)

---

## Application Overview

**Poducer** is a Rails 8 SaaS platform for podcast production that connects content creators with professional audio/video editors.

### Tech Stack
- **Framework**: Rails 8.0.2 with Ruby 3.3.5
- **Database**: SQLite (development) - needs consideration for production
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4.3
- **File Storage**: Active Storage (currently local disk)
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable + ActionCable
- **Authentication**: authentication-zero (session-based)

### User Roles
- **User**: Podcast creators who upload raw media and request production
- **Producer**: Professional editors who fulfill production requests
- **Admin**: System administrators (stub implementation)

### Core Workflow
```
User creates episode → Uploads raw audio/assets → Submits for editing
                                    ↓
Producer receives request → Edits content → Uploads deliverables
                                    ↓
User reviews → Approves → Episode published
```

---

## File Storage (AWS S3 Setup)

### Current State
- Using local disk storage via Active Storage
- Production files would be lost on server restart/redeploy
- Not suitable for MVP launch

### Recommended: AWS S3

#### Step 1: Create S3 Bucket

```bash
# Using AWS CLI
aws s3 mb s3://poducer-production --region us-east-1
```

Or via AWS Console:
1. Go to S3 → Create bucket
2. Bucket name: `poducer-production`
3. Region: Choose closest to your users
4. Block all public access: **Keep enabled**
5. Enable versioning (optional, recommended for recovery)

#### Step 2: Create IAM User

1. Go to IAM → Users → Create user
2. Name: `poducer-s3-access`
3. Attach policy: Create custom policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::poducer-production",
        "arn:aws:s3:::poducer-production/*"
      ]
    }
  ]
}
```

4. Create access keys and save them securely

#### Step 3: Add AWS Gem

Add to `Gemfile`:

```ruby
gem "aws-sdk-s3", require: false
```

Run:
```bash
bundle install
```

#### Step 4: Configure Storage

Update `config/storage.yml`:

```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: poducer-production
```

#### Step 5: Update Production Environment

In `config/environments/production.rb`:

```ruby
# Change from:
config.active_storage.service = :local

# To:
config.active_storage.service = :amazon
```

#### Step 6: Store Credentials

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

Add:

```yaml
aws:
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
```

#### Step 7: Configure CORS (for Direct Uploads)

Create bucket CORS configuration in AWS Console → S3 → Bucket → Permissions → CORS:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["PUT", "POST"],
    "AllowedOrigins": ["https://yourdomain.com"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

### Alternative: DigitalOcean Spaces

If you prefer DigitalOcean (S3-compatible, often cheaper):

```yaml
digitalocean:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:digitalocean, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:digitalocean, :secret_access_key) %>
  region: nyc3
  bucket: poducer-production
  endpoint: https://nyc3.digitaloceanspaces.com
```

### Cost Estimation (AWS S3)

| Storage | Cost/Month |
|---------|------------|
| 100 GB | ~$2.30 |
| 500 GB | ~$11.50 |
| 1 TB | ~$23.00 |

Plus data transfer: ~$0.09/GB outbound

---

## Hosting Recommendations

### Option 1: Kamal + VPS (Recommended)

Your app is already configured for Kamal deployment. This is the most cost-effective option.

**Recommended VPS Providers:**

| Provider | Plan | Cost/Month | Specs |
|----------|------|------------|-------|
| **Hetzner** | CPX31 | ~$15 | 4 vCPU, 8GB RAM, 160GB SSD |
| **DigitalOcean** | Droplet | $48 | 4 vCPU, 8GB RAM, 160GB SSD |
| **Vultr** | High Frequency | $48 | 4 vCPU, 8GB RAM, 128GB NVMe |

**Setup Steps:**

1. **Update `config/deploy.yml`:**

```yaml
service: poducer
image: your-dockerhub-username/poducer

servers:
  web:
    hosts:
      - YOUR_SERVER_IP
    labels:
      traefik.http.routers.poducer.rule: Host(`yourdomain.com`)
      traefik.http.routers.poducer_secure.entrypoints: websecure
      traefik.http.routers.poducer_secure.rule: Host(`yourdomain.com`)
      traefik.http.routers.poducer_secure.tls: true
      traefik.http.routers.poducer_secure.tls.certresolver: letsencrypt

proxy:
  ssl: true
  host: yourdomain.com

registry:
  username: your-dockerhub-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
  clear:
    RAILS_LOG_TO_STDOUT: "1"
    RAILS_SERVE_STATIC_FILES: "true"

volumes:
  - "poducer_storage:/rails/storage"

asset_path: /rails/public/assets
```

2. **Configure secrets in `.kamal/secrets`:**

```bash
KAMAL_REGISTRY_PASSWORD=your-dockerhub-token
RAILS_MASTER_KEY=$(cat config/master.key)
```

3. **Deploy:**

```bash
kamal setup    # First time only
kamal deploy   # Subsequent deploys
```

### Option 2: Render.com (Simpler, Higher Cost)

Create `render.yaml` in project root:

```yaml
services:
  - type: web
    name: poducer
    runtime: ruby
    buildCommand: "./bin/render-build.sh"
    startCommand: "bundle exec puma -C config/puma.rb"
    envVars:
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: poducer-db
          property: connectionString

databases:
  - name: poducer-db
    plan: starter
```

Create `bin/render-build.sh`:

```bash
#!/usr/bin/env bash
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails db:migrate
```

**Cost:** ~$25/month (web) + $7/month (database) = ~$32/month minimum

### Option 3: Fly.io

Create `fly.toml`:

```toml
app = "poducer"
primary_region = "iad"

[build]

[env]
  RAILS_LOG_TO_STDOUT = "enabled"
  RAILS_SERVE_STATIC_FILES = "true"

[http_service]
  internal_port = 3000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 1024
```

**Cost:** ~$15-30/month depending on usage

### Database Considerations

Your app uses SQLite with Solid Cache/Queue/Cable. For production:

**Option A: Keep SQLite (Simpler)**
- Works well with Kamal + persistent volume
- Use Litestack for better performance
- Requires volume backups

**Option B: PostgreSQL (Scalable)**
- Better for high concurrency
- Managed options: Render PostgreSQL, DigitalOcean Managed DB, AWS RDS
- Requires migration and config changes

For MVP, **SQLite with persistent volumes is acceptable** if you:
1. Configure automated backups
2. Use a VPS with persistent storage
3. Don't expect massive concurrent users initially

### Domain Setup

1. Point your domain's DNS to your server:
   - A record: `yourdomain.com` → `YOUR_SERVER_IP`
   - CNAME: `www` → `yourdomain.com`

2. Kamal will auto-configure SSL via Let's Encrypt

---

## Backend Work Required

### Critical (Must Fix Before Launch)

#### 1. Complete File Upload Refactor

The most recent commit indicates the file upload component refactor is incomplete.

**Current State:**
- New `file_upload_controller.js` created (690 lines)
- New shared partial `_file_upload.html.erb` created
- Some views updated, functionality may be broken

**Action Required:**
- Test all file upload flows thoroughly:
  - Podcast cover art upload
  - Episode assets upload
  - Episode raw audio upload
  - Producer deliverables upload
- Fix any broken upload endpoints
- Ensure Turbo Stream responses work correctly

#### 2. Remove Debug Statements

**Files with debug code to clean:**

`app/controllers/podcast_steps_controller.rb`:
```ruby
# REMOVE these lines:
Rails.logger.debug "Current step: #{step}"
Rails.logger.debug "Podcast name: '#{@podcast.name}'"
Rails.logger.debug "Podcast description: '#{@podcast.description}'"
Rails.logger.debug "Is valid for #{step}?: #{valid}"
Rails.logger.debug "Errors: #{@podcast.errors.full_messages}"
Rails.logger.debug "Storing errors in session: #{session[:validation_errors].inspect}"
```

`app/javascript/controllers/file_upload_controller.js`:
```javascript
// REMOVE these lines:
console.log("File upload controller connected")
console.log("Input target found:", this.inputTarget, "multiple:", this.multipleValue)
console.error("Input target not found!")
console.log("Files dropped:", files.length, files)
console.log("Files selected via input:", files.length, files)
```

#### 3. Configure Email Delivery

**Update `config/environments/production.rb`:**

```ruby
# For SendGrid:
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.sendgrid.net",
  port: 587,
  domain: "yourdomain.com",
  user_name: "apikey",
  password: Rails.application.credentials.dig(:sendgrid, :api_key),
  authentication: :plain,
  enable_starttls_auto: true
}
config.action_mailer.default_url_options = { host: "yourdomain.com", protocol: "https" }

# OR for Postmark:
config.action_mailer.delivery_method = :postmark
config.action_mailer.postmark_settings = {
  api_token: Rails.application.credentials.dig(:postmark, :api_token)
}
```

Add credentials:
```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
sendgrid:
  api_key: SG.xxxxx
# OR
postmark:
  api_token: xxxxx
```

#### 4. Enable File Size Validation

In `app/javascript/controllers/media_upload_controller.js`, uncomment and fix:

```javascript
// Uncomment and update:
if (this.maxSizeBytesValue && file.size > this.maxSizeBytesValue) {
  alert(`File is too large. Maximum size is ${this.maxSizeBytesValue / (1024 * 1024)} MB.`)
  return
}
```

### Important (Should Fix Before Launch)

#### 5. Implement Rate Limiting

Add `rack-attack` gem:

```ruby
# Gemfile
gem "rack-attack"
```

Create `config/initializers/rack_attack.rb`:

```ruby
class Rack::Attack
  # Throttle login attempts
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/sign_in" && req.post?
  end

  # Throttle file uploads
  throttle("uploads/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path.include?("/upload") && (req.post? || req.patch?)
  end

  # Throttle API requests
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end
end
```

#### 6. Add Error Tracking

Add Sentry or similar:

```ruby
# Gemfile
gem "sentry-ruby"
gem "sentry-rails"
```

Create `config/initializers/sentry.rb`:

```ruby
Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.25
  config.environment = Rails.env
end
```

#### 7. Configure Host Authorization

In `config/environments/production.rb`:

```ruby
# Uncomment and set:
config.hosts = [
  "yourdomain.com",
  "www.yourdomain.com"
]
```

### Nice to Have (Post-MVP)

#### 8. Subscription/Billing System

The User model has a commented TODO for plans:

```ruby
# app/models/user.rb
# TODO: Implementation plan options later
# enum plan: { base: 0, pro: 1, enterprise: 2 }
```

**For MVP:** This can wait. Consider Stripe integration post-launch.

#### 9. Admin Dashboard

Currently a stub at `Admin::UsersController`. Build out post-MVP.

#### 10. Push Notifications

Service worker code exists but is commented out. Enable post-MVP if needed.

---

## Reusable Dropzone Component

### Current Problem

You have **4 different upload controllers** with overlapping functionality:

| Controller | Lines | Purpose |
|------------|-------|---------|
| `file_upload_controller.js` | 690 | Full-featured with DirectUpload |
| `media_upload_controller.js` | 475 | Dual-mode (simple/AJAX) |
| `episode_upload_controller.js` | 89 | Minimal wrapper |
| `episode_assets_upload_controller.js` | 85 | Wizard-specific |

### Recommended: Unified Component

Keep and enhance `file_upload_controller.js` as the single source of truth. Here's how to make it fully reusable:

#### Step 1: Enhanced Controller

Create a consolidated controller at `app/javascript/controllers/file_upload_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = [
    "dropZone",
    "input",
    "fileList",
    "instructions",
    "preview",
    "progressBar",
    "submitButton"
  ]

  static values = {
    multiple: { type: Boolean, default: false },
    accept: { type: String, default: "*/*" },
    maxSizeBytes: { type: Number, default: 104857600 }, // 100MB default
    maxFiles: { type: Number, default: 10 },
    attachmentName: { type: String, default: "files" },
    labelParam: { type: String, default: "labels" },
    directUploadUrl: { type: String, default: "/rails/active_storage/direct_uploads" },
    deleteUrl: { type: String, default: "" },
    existingFiles: { type: Array, default: [] },
    uploadMode: { type: String, default: "direct" }, // "direct", "form", "ajax"
    ajaxUrl: { type: String, default: "" }
  }

  connect() {
    this.selectedFiles = new Map()
    this.uploadingFiles = new Set()
    this.renderExistingFiles()
    this.updateSubmitButton()
  }

  // Drag and Drop
  dragOver(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add("border-indigo-500", "bg-indigo-50")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-indigo-500", "bg-indigo-50")
  }

  drop(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-indigo-500", "bg-indigo-50")
    const files = Array.from(event.dataTransfer.files)
    this.processFiles(files)
  }

  // File Selection
  selectFiles(event) {
    const files = Array.from(event.target.files)
    this.processFiles(files)
    event.target.value = "" // Reset input for re-selection
  }

  processFiles(files) {
    files.forEach(file => {
      // Validate file type
      if (!this.validateFileType(file)) {
        this.showError(`${file.name}: Invalid file type`)
        return
      }

      // Validate file size
      if (!this.validateFileSize(file)) {
        const maxMB = this.maxSizeBytesValue / (1024 * 1024)
        this.showError(`${file.name}: File too large (max ${maxMB}MB)`)
        return
      }

      // Check max files
      if (!this.multipleValue && this.selectedFiles.size > 0) {
        this.selectedFiles.clear()
      }
      if (this.multipleValue && this.selectedFiles.size >= this.maxFilesValue) {
        this.showError(`Maximum ${this.maxFilesValue} files allowed`)
        return
      }

      // Deduplicate
      const key = `${file.name}-${file.size}-${file.lastModified}`
      if (!this.selectedFiles.has(key)) {
        this.selectedFiles.set(key, { file, label: file.name, signedId: null })
        this.uploadFile(key)
      }
    })

    this.renderFileList()
  }

  validateFileType(file) {
    if (this.acceptValue === "*/*") return true
    const accepted = this.acceptValue.split(",").map(t => t.trim())
    return accepted.some(type => {
      if (type.endsWith("/*")) {
        return file.type.startsWith(type.replace("/*", "/"))
      }
      return file.type === type || file.name.endsWith(type)
    })
  }

  validateFileSize(file) {
    return file.size <= this.maxSizeBytesValue
  }

  // Upload handling
  uploadFile(key) {
    const entry = this.selectedFiles.get(key)
    if (!entry || entry.signedId) return

    this.uploadingFiles.add(key)
    this.updateSubmitButton()

    const upload = new DirectUpload(entry.file, this.directUploadUrlValue, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener("progress", (event) => {
          const progress = (event.loaded / event.total) * 100
          this.updateProgress(key, progress)
        })
      }
    })

    upload.create((error, blob) => {
      this.uploadingFiles.delete(key)

      if (error) {
        this.selectedFiles.delete(key)
        this.showError(`Upload failed: ${error}`)
      } else {
        entry.signedId = blob.signed_id
        this.addHiddenInput(blob.signed_id)
      }

      this.renderFileList()
      this.updateSubmitButton()
    })
  }

  addHiddenInput(signedId) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = `${this.attachmentNameValue}[]`
    input.value = signedId
    input.dataset.signedId = signedId
    this.element.appendChild(input)
  }

  removeFile(event) {
    const key = event.currentTarget.dataset.key
    const entry = this.selectedFiles.get(key)

    if (entry?.signedId) {
      const input = this.element.querySelector(`input[data-signed-id="${entry.signedId}"]`)
      input?.remove()
    }

    this.selectedFiles.delete(key)
    this.renderFileList()
    this.updateSubmitButton()
  }

  removeExistingFile(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const id = event.currentTarget.dataset.id

    if (!confirm("Remove this file?")) return

    fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        "Accept": "text/vnd.turbo-stream.html, application/json"
      }
    }).then(response => {
      if (response.ok) {
        event.currentTarget.closest("[data-file-item]")?.remove()
      }
    })
  }

  updateLabel(event) {
    const key = event.currentTarget.dataset.key
    const entry = this.selectedFiles.get(key)
    if (entry) {
      entry.label = event.currentTarget.value
      this.updateLabelsInput()
    }
  }

  updateLabelsInput() {
    let labelsInput = this.element.querySelector(`input[name="${this.labelParamValue}"]`)
    if (!labelsInput) {
      labelsInput = document.createElement("input")
      labelsInput.type = "hidden"
      labelsInput.name = this.labelParamValue
      this.element.appendChild(labelsInput)
    }

    const labels = {}
    this.selectedFiles.forEach((entry, key) => {
      if (entry.signedId) {
        labels[entry.signedId] = entry.label
      }
    })
    labelsInput.value = JSON.stringify(labels)
  }

  // UI Rendering
  renderFileList() {
    if (!this.hasFileListTarget) return

    const items = []

    // Render pending/uploaded files
    this.selectedFiles.forEach((entry, key) => {
      items.push(this.renderFileItem(key, entry))
    })

    this.fileListTarget.innerHTML = items.join("")

    // Update instructions visibility
    if (this.hasInstructionsTarget) {
      this.instructionsTarget.classList.toggle("hidden", this.selectedFiles.size > 0)
    }
  }

  renderFileItem(key, entry) {
    const isUploading = this.uploadingFiles.has(key)
    const isComplete = !!entry.signedId

    return `
      <div data-file-item class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
        <div class="flex items-center gap-3 flex-1 min-w-0">
          ${this.getFileIcon(entry.file.type)}
          <div class="flex-1 min-w-0">
            <input type="text"
                   value="${this.escapeHtml(entry.label)}"
                   data-key="${key}"
                   data-action="change->file-upload#updateLabel"
                   class="block w-full text-sm border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                   ${isUploading ? "disabled" : ""}>
            <p class="text-xs text-gray-500 truncate">${this.formatFileSize(entry.file.size)}</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          ${isUploading ? '<span class="text-sm text-gray-500">Uploading...</span>' : ""}
          ${isComplete ? '<span class="text-green-500">✓</span>' : ""}
          <button type="button"
                  data-key="${key}"
                  data-action="click->file-upload#removeFile"
                  class="text-red-500 hover:text-red-700">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>
    `
  }

  renderExistingFiles() {
    if (!this.hasFileListTarget || !this.existingFilesValue.length) return

    const items = this.existingFilesValue.map(file => `
      <div data-file-item class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
        <div class="flex items-center gap-3 flex-1 min-w-0">
          ${this.getFileIcon(file.content_type)}
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(file.filename)}</p>
            <p class="text-xs text-gray-500">${this.formatFileSize(file.byte_size)}</p>
          </div>
        </div>
        ${this.deleteUrlValue ? `
          <button type="button"
                  data-url="${this.deleteUrlValue.replace(':id', file.id)}"
                  data-id="${file.id}"
                  data-action="click->file-upload#removeExistingFile"
                  class="text-red-500 hover:text-red-700">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        ` : ""}
      </div>
    `).join("")

    this.fileListTarget.innerHTML = items + this.fileListTarget.innerHTML
  }

  updateProgress(key, percent) {
    // Optional: Update progress UI
  }

  updateSubmitButton() {
    if (!this.hasSubmitButtonTarget) return
    this.submitButtonTarget.disabled = this.uploadingFiles.size > 0
  }

  showError(message) {
    // Simple alert for now - can be enhanced with toast notifications
    alert(message)
  }

  // Utilities
  getFileIcon(mimeType) {
    const type = mimeType?.split("/")[0] || "file"
    const icons = {
      audio: '<svg class="w-8 h-8 text-purple-500" fill="currentColor" viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>',
      video: '<svg class="w-8 h-8 text-blue-500" fill="currentColor" viewBox="0 0 24 24"><path d="M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z"/></svg>',
      image: '<svg class="w-8 h-8 text-green-500" fill="currentColor" viewBox="0 0 24 24"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>'
    }
    return icons[type] || '<svg class="w-8 h-8 text-gray-500" fill="currentColor" viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>'
  }

  formatFileSize(bytes) {
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
```

#### Step 2: Unified Partial

Your existing `app/views/shared/_file_upload.html.erb` is already well-structured. Ensure it uses the consolidated controller:

```erb
<%# app/views/shared/_file_upload.html.erb %>
<%#
  Required locals:
    - form: Form builder
    - attachment_name: Symbol (:assets, :cover_art, :deliverables)

  Optional locals:
    - multiple: Boolean (default: false)
    - accept: String (default: "*/*")
    - max_size_mb: Number (default: 100)
    - existing_files: Array of ActiveStorage attachments
    - delete_url: URL pattern with :id placeholder
    - label_param: String (default: "asset_labels")
    - section_label: String heading
    - instructions: Custom instructions text
%>

<% multiple ||= false %>
<% accept ||= "*/*" %>
<% max_size_mb ||= 100 %>
<% existing_files ||= [] %>
<% delete_url ||= "" %>
<% label_param ||= "asset_labels" %>
<% section_label ||= "Files" %>
<% instructions ||= multiple ? "Drop files here or click to browse" : "Drop file here or click to browse" %>

<% existing_files_json = existing_files.map { |f|
  {
    id: f.id,
    filename: f.filename.to_s,
    byte_size: f.byte_size,
    content_type: f.content_type
  }
}.to_json %>

<div data-controller="file-upload"
     data-file-upload-multiple-value="<%= multiple %>"
     data-file-upload-accept-value="<%= accept %>"
     data-file-upload-max-size-bytes-value="<%= max_size_mb * 1024 * 1024 %>"
     data-file-upload-attachment-name-value="<%= attachment_name %>"
     data-file-upload-label-param-value="<%= label_param %>"
     data-file-upload-delete-url-value="<%= delete_url %>"
     data-file-upload-existing-files-value="<%= existing_files_json %>"
     class="space-y-4">

  <% if local_assigns[:section_label] %>
    <h3 class="text-sm font-medium text-gray-700"><%= section_label %></h3>
  <% end %>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
    <%# Drop Zone %>
    <div data-file-upload-target="dropZone"
         data-action="dragover->file-upload#dragOver dragenter->file-upload#dragOver dragleave->file-upload#dragLeave drop->file-upload#drop"
         class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center cursor-pointer hover:border-indigo-400 transition-colors">

      <input type="file"
             data-file-upload-target="input"
             data-action="change->file-upload#selectFiles"
             accept="<%= accept %>"
             <%= "multiple" if multiple %>
             class="hidden">

      <div data-file-upload-target="instructions">
        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
          <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <p class="mt-2 text-sm text-gray-600"><%= instructions %></p>
        <p class="mt-1 text-xs text-gray-500">Max <%= max_size_mb %>MB per file</p>
      </div>

      <label class="mt-4 inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 cursor-pointer">
        Browse Files
        <input type="file"
               data-action="change->file-upload#selectFiles"
               accept="<%= accept %>"
               <%= "multiple" if multiple %>
               class="hidden">
      </label>
    </div>

    <%# File List %>
    <div data-file-upload-target="fileList" class="space-y-2 max-h-96 overflow-y-auto">
      <%# Existing and pending files rendered by JavaScript %>
    </div>
  </div>
</div>
```

#### Step 3: Usage Examples

**Podcast Cover Art (single image):**
```erb
<%= render "shared/file_upload",
    form: form,
    attachment_name: :cover_art,
    multiple: false,
    accept: "image/png,image/jpeg,image/webp",
    max_size_mb: 5,
    existing_files: @podcast.cover_art.attached? ? [@podcast.cover_art] : [],
    section_label: "Cover Art" %>
```

**Episode Assets (multiple files):**
```erb
<%= render "shared/file_upload",
    form: form,
    attachment_name: :assets,
    multiple: true,
    accept: "audio/*,video/*",
    max_size_mb: 500,
    existing_files: @episode.assets,
    delete_url: destroy_asset_podcast_episode_wizard_path(@podcast, @episode, id: ":id"),
    section_label: "Supporting Assets" %>
```

**Producer Deliverables:**
```erb
<%= render "shared/file_upload",
    form: form,
    attachment_name: :deliverables,
    multiple: true,
    max_size_mb: 1000,
    existing_files: @episode.deliverables,
    section_label: "Deliverable Files" %>
```

#### Step 4: Deprecate Old Controllers

After migrating all views to use the unified component:

1. Remove `episode_upload_controller.js`
2. Remove `episode_assets_upload_controller.js`
3. Keep `media_upload_controller.js` only if you need its specific AJAX batch upload features
4. Update all views to use only `file_upload_controller`

---

## Edge Cases & Issues

### Security Concerns

#### 1. File Upload Validation
**Issue:** Server-side validation is minimal.

**Fix:** Add model validations:

```ruby
# app/models/episode.rb
validate :validate_attachment_sizes
validate :validate_attachment_types

private

def validate_attachment_sizes
  max_size = 500.megabytes

  %i[raw_audio edited_audio cover_art].each do |attachment|
    if send(attachment).attached? && send(attachment).blob.byte_size > max_size
      errors.add(attachment, "is too large (max #{max_size / 1.megabyte}MB)")
    end
  end

  assets.each do |asset|
    if asset.byte_size > max_size
      errors.add(:assets, "contains files that are too large")
      break
    end
  end
end

def validate_attachment_types
  allowed_audio = %w[audio/mpeg audio/wav audio/aac audio/flac audio/mp4]
  allowed_video = %w[video/mp4 video/quicktime video/webm]
  allowed_images = %w[image/jpeg image/png image/webp]

  if raw_audio.attached? && !allowed_audio.include?(raw_audio.content_type)
    errors.add(:raw_audio, "must be an audio file")
  end

  if cover_art.attached? && !allowed_images.include?(cover_art.content_type)
    errors.add(:cover_art, "must be an image")
  end
end
```

#### 2. Content Security Policy
**Issue:** CSP may block inline scripts.

**Check:** `config/initializers/content_security_policy.rb` should allow:
- `script-src 'self'`
- `connect-src 'self'` (for Active Storage direct uploads)

#### 3. Session Fixation
**Issue:** Sessions should be regenerated on login.

**Fix:** Add to `SessionsController#create`:

```ruby
def create
  if user = User.authenticate_by(email: params[:email], password: params[:password])
    # Regenerate session to prevent fixation
    reset_session

    @session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
    cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
    redirect_to after_authentication_url
  else
    redirect_to sign_in_path, alert: "Invalid email or password"
  end
end
```

### Data Integrity

#### 4. Orphaned Attachments
**Issue:** Direct uploads may create orphaned blobs.

**Fix:** Add cleanup job:

```ruby
# app/jobs/cleanup_orphaned_blobs_job.rb
class CleanupOrphanedBlobsJob < ApplicationJob
  queue_as :default

  def perform
    ActiveStorage::Blob.unattached.where("created_at < ?", 1.day.ago).find_each(&:purge_later)
  end
end
```

Schedule in `config/initializers/solid_queue.rb` or via cron.

#### 5. Episode Number Uniqueness
**Issue:** Race condition could create duplicate episode numbers.

**Fix:** Add database-level unique index (already present) and handle in controller:

```ruby
def start_wizard
  @episode = @podcast.episodes.new(status: :draft)

  Episode.transaction do
    max_number = @podcast.episodes.maximum(:number) || 0
    @episode.number = max_number + 1
    @episode.save!
  end
rescue ActiveRecord::RecordNotUnique
  retry
end
```

### User Experience

#### 6. Large File Upload Timeout
**Issue:** Large files may timeout during upload.

**Mitigations:**
- Active Storage direct upload (already implemented)
- Increase Puma timeout in `config/puma.rb`:
  ```ruby
  worker_timeout 120
  ```
- Configure nginx/proxy timeouts if using reverse proxy

#### 7. Browser Back Button
**Issue:** Wizard state may be inconsistent on back navigation.

**Fix:** Add Turbo cache control:

```erb
<%# In wizard layouts %>
<meta name="turbo-cache-control" content="no-cache">
```

#### 8. Concurrent Editing
**Issue:** Multiple users editing same episode.

**Fix (post-MVP):** Add optimistic locking:

```ruby
# Migration
add_column :episodes, :lock_version, :integer, default: 0

# Model
class Episode < ApplicationRecord
  # Rails automatically uses lock_version for optimistic locking
end
```

### Performance

#### 9. N+1 Queries
**Issue:** Episode/podcast listings may have N+1 queries.

**Fix:** Add eager loading:

```ruby
# app/controllers/podcasts_controller.rb
def index
  @podcasts = current_user.podcasts
    .includes(:episodes, cover_art_attachment: :blob)
    .where.not(name: [nil, ""])
end
```

#### 10. SQLite Concurrency
**Issue:** SQLite has limited write concurrency.

**Mitigations for MVP:**
- Solid Queue runs jobs sequentially (good for SQLite)
- Keep write-heavy operations (uploads) quick
- Consider PostgreSQL for high-traffic production

---

## Pre-Launch Checklist

### Infrastructure

- [ ] **Server provisioned** (Hetzner/DigitalOcean/Vultr)
- [ ] **Domain DNS configured** (A record pointing to server IP)
- [ ] **SSL certificate** (auto-configured by Kamal/Let's Encrypt)
- [ ] **S3 bucket created** with proper IAM permissions
- [ ] **Backup strategy** configured (automated SQLite backups)

### Configuration

- [ ] **Production credentials** set (`rails credentials:edit`)
  - [ ] AWS S3 keys
  - [ ] Email service API key
  - [ ] (Optional) Sentry DSN
- [ ] **`config/deploy.yml`** updated with actual server IP and domain
- [ ] **`.kamal/secrets`** populated
- [ ] **Email delivery** configured and tested
- [ ] **Host authorization** configured with your domain

### Code Quality

- [ ] **Debug statements removed** from controllers and JavaScript
- [ ] **File upload component** tested end-to-end
- [ ] **All wizard flows** tested (podcast and episode)
- [ ] **Producer workflow** tested
- [ ] **Email flows** tested (registration, password reset)
- [ ] **Error tracking** configured (Sentry or similar)

### Security

- [ ] **Rate limiting** implemented
- [ ] **File validation** on server side
- [ ] **CORS configured** for S3 direct uploads
- [ ] **CSP headers** reviewed
- [ ] **Brakeman scan** passes with no critical issues

### Testing

- [ ] **Run full test suite**: `bin/rails test`
- [ ] **Run system tests**: `bin/rails test:system`
- [ ] **Manual testing** of all user flows
- [ ] **Mobile responsive** check
- [ ] **Load testing** (basic, ensure reasonable response times)

### Deployment

- [ ] **Initial deploy**: `kamal setup`
- [ ] **Database migrations** run automatically
- [ ] **Verify app loads** at your domain
- [ ] **Test file uploads** in production
- [ ] **Test email delivery** in production
- [ ] **Monitor logs**: `kamal logs`

---

## Post-Launch Monitoring

### Daily Checks (First Week)

```bash
# View application logs
kamal logs -f

# Check server resources
kamal app exec "df -h && free -m"

# Check database size
kamal app exec "ls -la storage/*.sqlite3"

# Check Active Storage blobs
kamal app exec "bin/rails runner 'puts ActiveStorage::Blob.count'"
```

### Alerts to Set Up

1. **Uptime monitoring** (UptimeRobot, Pingdom - free tiers available)
2. **Error alerts** (Sentry email notifications)
3. **Disk space alerts** (if using VPS monitoring)

### Weekly Tasks

- Review error logs for patterns
- Check backup integrity
- Monitor storage usage (S3 costs)
- Review user feedback

### Scaling Indicators

Consider scaling when you see:
- Response times > 500ms consistently
- SQLite write contention errors
- Storage approaching limits
- Background job queue backing up

---

## Summary

**Minimum Required for MVP Launch:**

1. **File Storage**: Set up AWS S3 (~30 mins)
2. **Hosting**: Deploy with Kamal to Hetzner/DO (~1 hour)
3. **Email**: Configure SendGrid/Postmark (~30 mins)
4. **Fix Upload Component**: Test and fix any broken flows (~2-4 hours)
5. **Remove Debug Code**: Clean up console.log and Rails.logger.debug (~30 mins)
6. **Basic Security**: Rate limiting, file validation (~1-2 hours)

**Total Estimated Effort**: 1-2 days of focused work

**Monthly Operating Costs (Estimate)**:
- VPS (Hetzner CPX31): ~$15/month
- S3 Storage (100GB): ~$5/month
- Email (SendGrid free tier): $0
- Domain: Already owned

**Total**: ~$20/month to start

Good luck with your launch!
