Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Practitioner auth
      post "practitioner/login", to: "practitioner_auth#login"

      # Client auth
      post "client/login", to: "client_auth#login"
      post "client/accept_invite", to: "client_auth#accept_invite"
      post "client/forgot_password", to: "client_auth#forgot_password"
      post "client/reset_password", to: "client_auth#reset_password"
      post "client/refresh", to: "client_auth#refresh"
      post "client/logout", to: "client_auth#logout"

      # Practitioner-facing: manage clients
      resources :clients, only: [ :index, :show, :create, :update, :destroy ] do
        get  :roster_summary, on: :collection
        post :resend_invite, on: :member
      end

      # Practitioner schedule (cross-client)
      resources :appointments, only: [ :index ], controller: "practitioner/schedule" do
        collection { get :upcoming }
      end

      # Practitioner-facing: view client entries
      resources :clients, only: [] do
        resources :food_entries, only: [ :index ], controller: "practitioner/food_entries"
        resources :symptoms, only: [ :index ], controller: "practitioner/symptoms"
        resources :energy_logs, only: [ :index ], controller: "practitioner/energy_logs"
        resources :sleep_logs, only: [ :index ], controller: "practitioner/sleep_logs"
        resources :water_intakes, only: [ :index ], controller: "practitioner/water_intakes"
        resources :supplements, only: [ :index ], controller: "practitioner/supplements"
        resources :notes, only: [ :index, :show, :create, :update, :destroy ],
                          controller: "practitioner/notes"
        resources :appointments, only: [ :index, :show, :create, :update, :destroy ],
                                  controller: "practitioner/appointments"
        get :daily_aggregates, controller: "practitioner/daily_aggregates", action: :show
      end

      # Client-facing: manage own entries
      namespace :client do
        resources :food_entries, only: [ :index, :show, :create, :update, :destroy ]
        resources :symptoms, only: [ :index, :show, :create, :update, :destroy ]
        resources :energy_logs, only: [ :index, :show, :create, :update, :destroy ]
        resources :sleep_logs, only: [ :index, :show, :create, :update, :destroy ]
        resources :water_intakes, only: [ :index, :show, :create, :update, :destroy ]
        resources :supplements, only: [ :index, :show, :create, :update, :destroy ]
        resources :consents, only: [ :index, :create ]
        get "profile", to: "profile#show"
        patch "profile", to: "profile#update"
        patch "password", to: "password#update"
        post "sync", to: "sync#create"
      end

      # GDPR
      post "gdpr/export", to: "gdpr#export"
      delete "gdpr/delete", to: "gdpr#delete_data"
    end
  end
end
