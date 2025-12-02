Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "home" => "documents#index", as: :documents_home

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "/vectors", to: "vectors#index"


  get "search" => "documents#search"
  get "search_style" => "documents#search_style"
  get "search_hybrid", to: "documents#search_hybrid"


  # Defines the root path route ("/")
  # root "posts#index"
end
