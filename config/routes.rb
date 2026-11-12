Rails.application.routes.draw do
  # Public landing page. Latvian is the default locale at `/` (no prefix) and
  # English lives at `/en`. Until the LV copy is written, `/` redirects to `/en`
  # (handled in LandingController#show). See agents/docs/landing-page-plan.md.
  scope "(:locale)", locale: /en/ do
    root "landing#show"
  end

  resource :session
  resources :passwords, param: :token

  # One-click demo login (sign-up is disabled for the demo).
  post "demo_session", to: "demo_sessions#create", as: :demo_session

  # Registration — creating a new account + user in one step
  resource :registration, only: %i[new create]
  resource :account, only: %i[edit update]
  resources :products

  resources :clients

  resources :invoices, shallow: true do
    member do
      get :print
      get :pdf
      get :ubl
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

  # The authenticated app home — `/` is the public landing page.
  get "dashboard" => "dashboards#show", as: :dashboard
end
