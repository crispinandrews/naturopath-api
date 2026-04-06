Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Practitioner auth
      post "practitioner/register", to: "practitioner_auth#register"
      post "practitioner/login", to: "practitioner_auth#login"

      # Client auth
      post "client/login", to: "client_auth#login"
      post "client/accept_invite", to: "client_auth#accept_invite"

      # Practitioner-facing: manage clients
      resources :clients, only: [:index, :show, :create, :update, :destroy]

      # Practitioner-facing: view client entries
      resources :clients, only: [] do
        resources :food_entries, only: [:index], controller: "practitioner/food_entries"
        resources :symptoms, only: [:index], controller: "practitioner/symptoms"
        resources :energy_logs, only: [:index], controller: "practitioner/energy_logs"
        resources :sleep_logs, only: [:index], controller: "practitioner/sleep_logs"
        resources :water_intakes, only: [:index], controller: "practitioner/water_intakes"
        resources :supplements, only: [:index], controller: "practitioner/supplements"
      end

      # Client-facing: manage own entries
      namespace :client do
        resources :food_entries, only: [:index, :show, :create, :update, :destroy]
        resources :symptoms, only: [:index, :show, :create, :update, :destroy]
        resources :energy_logs, only: [:index, :show, :create, :update, :destroy]
        resources :sleep_logs, only: [:index, :show, :create, :update, :destroy]
        resources :water_intakes, only: [:index, :show, :create, :update, :destroy]
        resources :supplements, only: [:index, :show, :create, :update, :destroy]
        resources :consents, only: [:index, :create]
        get "profile", to: "profile#show"
      end

      # GDPR
      post "gdpr/export", to: "gdpr#export"
      delete "gdpr/delete", to: "gdpr#delete_data"
    end
  end
end
