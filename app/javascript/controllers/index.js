// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
// Explicit registration to satisfy static analyzers for custom controllers
import EpisodeAssetsUploadController from "controllers/episode_assets_upload_controller"
application.register("episode-assets-upload", EpisodeAssetsUploadController)
application.register("episode-upload", EpisodeAssetsUploadController)