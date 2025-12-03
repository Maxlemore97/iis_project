Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  post "upload_trec", to: "home#upload_trec"
  delete "delete_all_documents", to: "home#delete_all"

  post "upload_query_trec", to: "home#upload_query_trec"
  delete "delete_all_queries", to: "home#delete_all_queries"

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "/vectors", to: "vectors#index"
  get "/keywords", to: "keywords#index"

  get "documents" => "documents#index"
  resources :documents_hybrid, only: [:index]
  resources :documents_elastic, only: [:index]

  # Defines the root path route ("/")
  # root "posts#index"
end
