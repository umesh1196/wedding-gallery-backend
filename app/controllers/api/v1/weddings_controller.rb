module Api
  module V1
    class WeddingsController < BaseController
      include Pagy::Backend

      def create
        wedding = current_studio.weddings.new(create_params)
        wedding.password = create_params[:password]
        wedding.save!

        render_success(WeddingBlueprint.render_as_hash(wedding), status: :created)
      end

      def index
        pagy_obj, weddings = pagy(current_studio.weddings.order(created_at: :desc))

        render_success(
          WeddingBlueprint.render_as_hash(weddings),
          meta: {
            count: weddings.size,
            page: pagy_obj.page,
            pages: pagy_obj.pages,
            total_count: pagy_obj.count
          }
        )
      end

      def show
        render_success(WeddingBlueprint.render_as_hash(wedding))
      end

      def update
        wedding.assign_attributes(update_params.except(:password))
        wedding.password = update_params[:password] if update_params[:password].present?
        wedding.save!

        render_success(WeddingBlueprint.render_as_hash(wedding))
      end

      def destroy
        wedding.update!(is_active: false)
        render_success(WeddingBlueprint.render_as_hash(wedding))
      end

      def upload_hero
        result = WeddingHeroUploadService.new(wedding: wedding, upload: params[:file]).call
        render_success(result)
      rescue WeddingHeroUploadService::UploadError => e
        render_error(e.message, status: :unprocessable_entity, code: "invalid_upload")
      end

      private

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:slug])
      end

      def create_params
        params.require(:wedding).permit(
          :couple_name, :wedding_date, :slug, :password, :expires_at,
          :allow_download, :allow_comments, :hero_image_url, metadata: {}
        )
      end

      def update_params
        params.require(:wedding).permit(
          :couple_name, :wedding_date, :slug, :password, :expires_at,
          :allow_download, :allow_comments, :hero_image_url, :is_active, metadata: {}
        )
      end
    end
  end
end
