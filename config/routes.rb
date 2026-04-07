Rails.application.routes.draw do
  # Rails built-in health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Custom health endpoint
  get "health" => "health#show"

  namespace :api do
    namespace :v1 do
      # Auth routes will be added here (AUTH epic)
    end
  end
end
