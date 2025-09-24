Rails.application.routes.draw do
  namespace :admin do
    resources :users
  end

  namespace :producer do
    resources :episodes do
      member do
        patch :start_editing
        patch :complete_editing
      end
    end
  end

  resources :podcasts do
    collection do
      post :start_wizard
    end

    resources :episodes do
      member do
        patch :submit_episode
        patch :start_editing
        patch :complete_editing
        patch :publish_episode
        patch :revert_to_draft
      end
    end

    resources :wizard, only: [ :show, :update ], controller: "podcast_steps"

    # Simpler route for deleting media files
    delete "media/:media_id", to: "podcast_steps#destroy_media", as: "delete_media"
  end

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
