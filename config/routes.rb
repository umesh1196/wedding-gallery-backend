Rails.application.routes.draw do
  get "up"     => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  namespace :api do
    namespace :v1 do
      post "g/:studio_slug/:wedding_slug/verify", to: "gallery#verify"
      namespace :g, module: "gallery", path: "g" do
        get ":studio_slug/:wedding_slug", to: "bootstraps#show"
        get ":studio_slug/:wedding_slug/ceremonies", to: "ceremonies#index"
        get ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/photos", to: "photos#index"
        post ":studio_slug/:wedding_slug/photos/:photo_id/like", to: "likes#create"
        delete ":studio_slug/:wedding_slug/photos/:photo_id/like", to: "likes#destroy"
        get ":studio_slug/:wedding_slug/likes", to: "likes#index"
        get ":studio_slug/:wedding_slug/shortlist", to: "shortlists#show"
        post ":studio_slug/:wedding_slug/shortlist/photos", to: "shortlists#add_photos"
        delete ":studio_slug/:wedding_slug/shortlist/photos/:photo_id", to: "shortlists#remove_photo"
        patch ":studio_slug/:wedding_slug/shortlist/reorder", to: "shortlists#reorder"
      end
      post "auth/signup", to: "auth#signup"
      post "auth/login",  to: "auth#login"
      get  "auth/me",     to: "auth#me"
      patch "studio",     to: "studios#update"
      post "studio/logo", to: "studios#upload_logo"
      post "studio/watermark", to: "studios#upload_watermark"
      resources :storage_connections, only: [ :index, :create, :update, :destroy ], controller: "storage_connections"
      resources :upload_batches, only: [ :show ], controller: "upload_batches"
      resources :weddings, param: :slug, except: [ :new, :edit ] do
        post :hero, on: :member, action: :upload_hero
        resources :shortlists, only: [ :index, :show ], controller: "shortlists"
        resources :ceremonies, except: [ :new, :edit ], controller: "ceremonies", param: :slug do
          post :cover, on: :member, action: :upload_cover
          patch :reorder, on: :collection
          post :seed, on: :collection
          resources :photos, only: [ :index ], controller: "photos", param: :id do
            collection do
              post "import/discover", action: :discover_import
              post :import
              post :presign
              patch :reorder
            end
          end
        end
      end

      resources :photos, only: [ :destroy ], controller: "photos" do
        post :confirm, on: :member
        post :retry_import, on: :member
        post :retry_processing, on: :member
        post :set_cover, on: :member
      end
    end
  end
end
