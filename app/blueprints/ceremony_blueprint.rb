class CeremonyBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :slug, :cover_image_key, :description, :scheduled_at, :sort_order, :photo_count, :video_count

  field :cover_image_url do |ceremony|
    ceremony.cover_asset_url
  end
end
