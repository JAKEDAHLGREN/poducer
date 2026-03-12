# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Run all tests:**
```bash
RAILS_MASTER_KEY=$(cat config/master.key) bundle exec rails test
```

**Run a single test file:**
```bash
RAILS_MASTER_KEY=$(cat config/master.key) bundle exec ruby -Itest test/controllers/episodes_controller_test.rb
```

**Run a specific test by name:**
```bash
RAILS_MASTER_KEY=$(cat config/master.key) bundle exec ruby -Itest test/controllers/episodes_controller_test.rb -n test_name
```

**Skip system tests (no browser needed):**
```bash
RAILS_MASTER_KEY=$(cat config/master.key) bundle exec ruby -Itest $(find test -name '*_test.rb' | grep -v system/ | tr '\n' ' ')
```

**Linting:**
```bash
bundle exec rubocop
bundle exec brakeman
```

**Start dev server:**
```bash
bin/dev
```

**Database:**
```bash
bin/rails db:migrate
bin/rails db:seed
```

## Architecture

### Roles & Routing
Three user roles (enum: `user`, `producer`, `admin`) drive routing in `ApplicationController#root_path_for_role`:
- `user` → `/podcasts`
- `producer` → `/producer/episodes`
- `admin` → `/admin/users`

### Multi-Step Wizards (Wicked Gem)
Podcast creation and episode creation use Wicked-based step controllers:
- `PodcastStepsController` — steps: `:overview`, `:media`, `:categories`, `:summary`
- `EpisodeStepsController` — steps: `:overview`, `:assets`, `:details`, `:summary`

These controllers handle validation per-step (using `context:` in `valid?`) and publish/finalize records on the summary step.

### Episode State Machine
`Episode` has 7 statuses with explicit transition methods:
```
draft → edit_requested → editing → awaiting_user_review → ready_to_publish → episode_complete
                                                                            ↘ archived
```
Transition methods: `submit_for_editing!`, `start_editing!`, `complete_editing!`, `revert_to_draft!`, `re_submit_for_editing!`, `approve_episode!`, `publish_episode!`.

State transitions broadcast Turbo Stream updates for real-time UI.

### Two Episode Upload Flows
1. **User assets** — `EpisodeStepsController` (raw audio, cover art, supplemental assets)
2. **Producer deliverables** — `Producer::EpisodesController` (edited audio, deliverables)

Both use the `FileAttachable` concern, which handles JSON, Turbo Stream, and HTML responses from a unified `attach_files` method.

### File Labels (Blob Metadata)
ActiveStorage attachments store display labels in blob custom metadata. The `EpisodeLabelable` concern (`process_episode_asset_labels`, `process_episode_cover_art_label`) reads labels from params and persists them to `blob.custom_metadata`. The Stimulus `file_upload_controller.js` serializes labels to JSON for form submission.

### Controller Concerns
- **`Authorizable`** — `authorize_resource_access(resource)` enforces ownership; admins bypass all checks.
- **`SetPodcastAndEpisode`** — before-action helpers that scope episode lookups through `podcast.episodes`.
- **`FileAttachable`** — unified file attachment with multi-format responses.
- **`EpisodeLabelable`** — blob metadata label persistence.

### Frontend
- Hotwire (Turbo + Stimulus) — no build step, managed via ImportMap
- Tailwind CSS 4 via `tailwindcss-rails`
- `file_upload_controller.js` — full drag-and-drop with DirectUpload, labels, MIME validation, progress tracking

### Known Test Issues
- 3 pre-existing failures: `complete_editing` tests in `episodes_controller_test.rb` (lines 58, 86) and `producer/episodes_controller_test.rb` (line 18) — these don't attach required audio/deliverables before the state transition.
- System tests require Chrome; skip the `test/system/` directory for quick runs.
