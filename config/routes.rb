Rails.application.routes.draw do
  namespace :admin do
    resources :users
  end

  namespace :producer do
    resources :episodes do
      member do
        patch :start_editing
        patch :complete_editing
        patch :upload_assets
      end
    end
  end

  resources :podcasts do
    collection do
      post :start_wizard
    end

    resources :episodes do
      collection do
        post :start_wizard
      end

      resources :wizard, only: [ :show, :update ], controller: "episode_steps" do
        # Immediate uploads for episode wizard (avoid name collision with step :assets)
        patch :upload_assets, on: :collection, action: :assets
        patch :upload_raw_audio, on: :collection, action: :raw_audio
        delete "uploads/assets/:attachment_id", to: "episode_steps#destroy_asset", as: :upload_asset
        delete "uploads/raw_audio", to: "episode_steps#destroy_raw_audio"
      end
      member do
        patch :submit_episode
        patch :start_editing
        patch :complete_editing
        patch :re_submit_for_editing
        patch :approve_episode
        patch :publish_episode
        patch :revert_to_draft
      end
    end

    resources :wizard, only: [ :show, :update ], controller: "podcast_steps"
  end

# Explicit route to remove an uploaded episode asset from the wizard (supports DELETE and fallback GET)
match "/podcasts/:podcast_id/episodes/:episode_id/wizard/uploads/assets/:attachment_id",
      to: "episode_steps#destroy_asset",
      as: :wizard_destroy_asset,
      via: [ :delete, :get ]

  resources :dashboards, only: [ :index ]
  get "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resources :sessions, only: [ :index, :show, :destroy ]
  resource :password, only: [ :edit, :update ]
  namespace :identity do
    resource :email, only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset, only: [ :new, :edit, :create, :update ]
  end

  root "application#root"

  get "up" => "rails/health#show", as: :rails_health_check

  delete "sign_out", to: "sessions#destroy_current"
end
