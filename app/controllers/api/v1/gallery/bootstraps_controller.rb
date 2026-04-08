module Api
  module V1
    module Gallery
      class BootstrapsController < BaseController
        def show
          render_success(
            {
              couple_name: current_wedding.couple_name,
              wedding_date: current_wedding.wedding_date,
              hero_image_url: current_wedding.hero_asset_url,
              allow_download: current_wedding.allow_download,
              allow_comments: current_wedding.allow_comments,
              branding: {
                slug: current_studio.slug,
                studio_name: current_studio.studio_name,
                color_primary: current_studio.color_primary,
                color_accent: current_studio.color_accent,
                font_heading: current_studio.font_heading,
                font_body: current_studio.font_body,
                logo_url: current_studio.logo_asset_url,
                watermark_url: current_studio.watermark_asset_url,
                watermark_opacity: current_studio.watermark_opacity
              }
            }
          )
        end
      end
    end
  end
end
