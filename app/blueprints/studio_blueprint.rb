class StudioBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :studio_name, :slug, :phone, :plan, :plan_expires_at,
         :color_primary, :color_accent, :font_heading, :font_body,
         :watermark_opacity, :logo_key, :watermark_key

  field :logo_url do |studio|
    studio.logo_asset_url
  end

  field :watermark_url do |studio|
    studio.watermark_asset_url
  end
end
