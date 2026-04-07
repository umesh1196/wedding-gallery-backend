module Api
  module V1
    class StudiosController < BaseController
      # PATCH /api/v1/studio
      def update
        current_studio.update!(studio_params)
        render_success(StudioBlueprint.render_as_hash(current_studio))
      end

      # POST /api/v1/studio/logo
      def upload_logo
        result = upload_asset(:logo)
        render_success(result) if result
      end

      # POST /api/v1/studio/watermark
      def upload_watermark
        result = upload_asset(:watermark)
        render_success(result) if result
      end

      private

      def studio_params
        params.require(:studio).permit(
          :studio_name,
          :slug,
          :phone,
          :logo_url,
          :color_primary,
          :color_accent,
          :font_heading,
          :font_body,
          :watermark_url,
          :watermark_opacity
        )
      end

      def upload_asset(asset_type)
        StudioAssetUploadService.new(
          studio: current_studio,
          upload: params[:file],
          asset_type: asset_type
        ).call
      rescue StudioAssetUploadService::UploadError => e
        render_error(e.message, status: :unprocessable_entity, code: "invalid_upload")
        nil
      end
    end
  end
end
