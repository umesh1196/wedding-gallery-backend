Rails.application.routes.draw do
  get "up"     => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  namespace :api do
    namespace :v1 do
      post "auth/signup", to: "auth#signup"
      post "auth/login",  to: "auth#login"
      get  "auth/me",     to: "auth#me"
      patch "studio",     to: "studios#update"
      post "studio/logo", to: "studios#upload_logo"
      post "studio/watermark", to: "studios#upload_watermark"
      resources :weddings, param: :slug, except: [ :new, :edit ] do
        post :hero, on: :member, action: :upload_hero
        resources :ceremonies, except: [ :new, :edit ], controller: "ceremonies", param: :slug do
          post :cover, on: :member, action: :upload_cover
          patch :reorder, on: :collection
          post :seed, on: :collection
        end
      end
    end
  end
end
