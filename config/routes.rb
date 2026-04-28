Rails.application.routes.draw do
  get "up"     => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  namespace :api do
    namespace :v1 do
      post "g/:studio_slug/:wedding_slug/verify", to: "gallery#verify"
      namespace :g, module: "gallery", path: "g" do
        get "shared/:token", to: "shared_links#show"
        get "albums/shared/:token", to: "shared_albums#show"
        get "albums/shared/:token/photos", to: "shared_albums#photos"
        get ":studio_slug/:wedding_slug", to: "bootstraps#show"
        post ":studio_slug/:wedding_slug/share", to: "share_links#create"
        get ":studio_slug/:wedding_slug/print_selection_buckets", to: "print_selection_buckets#index"
        get ":studio_slug/:wedding_slug/print_selection_buckets/:slug", to: "print_selection_buckets#show"
        get ":studio_slug/:wedding_slug/print_selection_buckets/:slug/photos", to: "print_selection_buckets#photos"
        post ":studio_slug/:wedding_slug/print_selection_buckets/:slug/photos", to: "print_selection_buckets#add_photos"
        delete ":studio_slug/:wedding_slug/print_selection_buckets/:slug/photos/:photo_id", to: "print_selection_buckets#remove_photo"
        get ":studio_slug/:wedding_slug/ceremonies", to: "ceremonies#index"
        get ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums", to: "albums#index"
        post ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums", to: "albums#create"
        get ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug", to: "albums#show"
        get ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug/photos", to: "albums#photos"
        patch ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug", to: "albums#update"
        delete ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug", to: "albums#destroy"
        post ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos", to: "album_photos#create"
        delete ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos/:photo_id", to: "album_photos#destroy"
        patch ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/reorder", to: "album_photos#reorder"
        post ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/cover", to: "album_photos#cover"
        post ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/share_links", to: "album_share_links#create"
        get ":studio_slug/:wedding_slug/people", to: "people#index"
        get ":studio_slug/:wedding_slug/people/:person_id/photos", to: "people#photos"
        post ":studio_slug/:wedding_slug/face-search", to: "face_search#create"
        get ":studio_slug/:wedding_slug/ceremonies/:ceremony_slug/photos", to: "photos#index"
        get ":studio_slug/:wedding_slug/photos/:photo_id/comments", to: "comments#index"
        post ":studio_slug/:wedding_slug/photos/:photo_id/comments", to: "comments#create"
        delete ":studio_slug/:wedding_slug/comments/:id", to: "comments#destroy"
        get ":studio_slug/:wedding_slug/photos/:photo_id/download", to: "downloads#download_photo"
        post ":studio_slug/:wedding_slug/downloads", to: "downloads#create"
        get ":studio_slug/:wedding_slug/downloads/:id", to: "downloads#show"
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
        get :comments, on: :member, controller: "comments", action: :index
        post :hero, on: :member, action: :upload_hero
        post :run_face_recognition, on: :member
        resources :shortlists, only: [ :index, :show ], controller: "shortlists"
        resources :print_selection_buckets, except: [ :new, :edit ], controller: "print_selection_buckets", param: :slug do
          member do
            get :photos
            post :lock
            delete :lock, action: :unlock
          end
        end
        resources :ceremonies, except: [ :new, :edit ], controller: "ceremonies", param: :slug do
          resources :albums, except: [ :new, :edit ], controller: "albums", param: :slug
          post "albums/:album_slug/photos", to: "album_photos#create"
          delete "albums/:album_slug/photos/:photo_id", to: "album_photos#destroy"
          patch "albums/:album_slug/reorder", to: "album_photos#reorder"
          post "albums/:album_slug/cover", to: "album_photos#cover"
          post "albums/:album_slug/share_links", to: "album_share_links#create"
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
        post :retry_face_recognition, on: :member
        post :set_cover, on: :member
      end
    end
  end
end
