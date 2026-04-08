module Gallery
  class PayloadBuilder
    def initialize(wedding:)
      @wedding = wedding
    end

    def call
      {
        couple_name: @wedding.couple_name,
        wedding_date: @wedding.wedding_date,
        hero_image_url: @wedding.hero_asset_url,
        allow_download: @wedding.allow_download,
        allow_comments: @wedding.allow_comments,
        branding: {
          slug: @wedding.studio.slug,
          studio_name: @wedding.studio.studio_name,
          color_primary: @wedding.studio.color_primary,
          color_accent: @wedding.studio.color_accent,
          font_heading: @wedding.studio.font_heading,
          font_body: @wedding.studio.font_body,
          logo_url: @wedding.studio.logo_asset_url,
          watermark_url: @wedding.studio.watermark_asset_url,
          watermark_opacity: @wedding.studio.watermark_opacity
        }
      }
    end
  end
end
