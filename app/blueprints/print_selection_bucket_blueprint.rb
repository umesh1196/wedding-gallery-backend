class PrintSelectionBucketBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :slug, :selection_limit, :selected_count, :locked_at

  field :remaining_count do |bucket|
    bucket.remaining_count
  end

  field :locked do |bucket|
    bucket.locked?
  end

  field :cover_photo_url do |bucket|
    photo = bucket.cover_photo
    next if photo.blank?

    PhotoUrlBuilder.new(photo).urls[:preview]
  end

  field :last_updated_at do |bucket|
    bucket.updated_at
  end
end
