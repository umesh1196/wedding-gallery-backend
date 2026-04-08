module Api
  module V1
    class GalleryController < ApplicationController
      def verify
        return render_error("Gallery expired", status: :gone, code: "gallery_expired") if wedding.expired?

        unless wedding.authenticate(params.require(:password))
          return render_error("Unauthorized", status: :unauthorized, code: "unauthorized")
        end

        _session, token = GallerySession.issue_for!(
          wedding: wedding,
          ip: request.remote_ip,
          user_agent: request.user_agent
        )

        render_success(
          {
            session_token: token,
            gallery: gallery_payload(wedding)
          }
        )
      end

      def show
        render_success(gallery_payload(current_wedding))
      end

      private

      def wedding
        @wedding ||= Wedding.joins(:studio).find_by!(
          slug: params[:wedding_slug],
          studios: { slug: params[:studio_slug] }
        )
      end

      def gallery_payload(record)
        {
          couple_name: record.couple_name,
          wedding_date: record.wedding_date,
          hero_image_url: record.hero_asset_url,
          allow_download: record.allow_download,
          allow_comments: record.allow_comments,
          branding: {
            slug: record.studio.slug,
            studio_name: record.studio.studio_name,
            color_primary: record.studio.color_primary,
            color_accent: record.studio.color_accent,
            font_heading: record.studio.font_heading,
            font_body: record.studio.font_body,
            logo_url: record.studio.logo_asset_url,
            watermark_url: record.studio.watermark_asset_url,
            watermark_opacity: record.studio.watermark_opacity
          }
        }
      end
    end
  end
end
