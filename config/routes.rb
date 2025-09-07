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
    resources :episodes do
      member do
        patch :submit_episode
        patch :start_editing
        patch :complete_editing
        patch :publish_episode
        patch :revert_to_draft
      end
    end
  end

  resources :dashboards, only: [ :index ]
  get  "sign_in",  to: "sessions#new"
  post "sign_in",  to: "sessions#create"
  get  "sign_up",  to: "registrations#new"
  post "sign_up",  to: "registrations#create"
  resources :sessions, only: [ :index, :show, :destroy ]
  resource  :password, only: [ :edit, :update ]
  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end

  root "application#root"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  delete "sign_out", to: "sessions#destroy_current"
end
