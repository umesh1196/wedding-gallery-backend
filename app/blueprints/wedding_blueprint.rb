class WeddingBlueprint < Blueprinter::Base
  identifier :id

  fields :couple_name, :wedding_date, :slug, :hero_image_key, :is_active,
         :expires_at, :allow_download, :allow_comments, :total_photos,
         :total_videos, :metadata

  field :hero_image_url do |wedding|
    wedding.hero_asset_url
  end

  field :expired do |wedding|
    wedding.expired?
  end

  field :ceremony_count do |wedding|
    wedding.ceremony_count
  end

  field :ceremonies do |wedding|
    CeremonyBlueprint.render_as_hash(wedding.ceremonies.order(:sort_order))
  end
end
