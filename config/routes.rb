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
    end
  end
end
