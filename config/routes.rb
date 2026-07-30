Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Registration — creating a new account + user in one step
  resource :registration, only: %i[new create]
  resource :account, only: %i[edit update]
  resources :products

  resources :clients

  resources :invoices, shallow: true do
    member do
      get :print
    end
    resources :line_items, only: %i[new create edit update destroy]

    # Status transitions — modelled as REST resources, not custom member actions.
    resources :invoice_sends, only: %i[create]
    resources :invoice_payments, only: %i[create]
    resources :invoice_voids, only: %i[create]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboards#show"
end
