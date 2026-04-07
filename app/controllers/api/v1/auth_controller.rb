module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_studio!, only: [ :signup, :login ]

      # POST /api/v1/auth/signup
      def signup
        studio = Studio.new(signup_params)

        if studio.save
          token = JwtService.encode({ studio_id: studio.id })
          render_success(
            { token: token, studio: StudioBlueprint.render_as_hash(studio) },
            status: :created
          )
        else
          render_error(
            studio.errors.full_messages.join(", "),
            status: :unprocessable_entity,
            code: "validation_error"
          )
        end
      end

      # POST /api/v1/auth/login
      def login
        studio = Studio.find_by(email: login_params[:email]&.downcase)

        if studio&.authenticate(login_params[:password])
          token = JwtService.encode({ studio_id: studio.id })
          render_success({ token: token, studio: StudioBlueprint.render_as_hash(studio) })
        else
          render_error("Invalid email or password", status: :unauthorized, code: "invalid_credentials")
        end
      end

      # GET /api/v1/auth/me
      def me
        render_success(StudioBlueprint.render_as_hash(current_studio))
      end

      private

      def signup_params
        params.require(:studio).permit(:email, :password, :password_confirmation, :studio_name, :phone)
      end

      def login_params
        params.require(:studio).permit(:email, :password)
      end
    end
  end
end
