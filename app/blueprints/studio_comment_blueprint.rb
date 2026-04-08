class StudioCommentBlueprint < Blueprinter::Base
  identifier :id

  fields :body, :created_at

  field :visitor_name do |comment|
    comment.visitor_name_snapshot
  end

  field :photo_id do |comment|
    comment.photo_id
  end

  field :ceremony_slug do |comment|
    comment.photo.ceremony.slug
  end

  field :ceremony_name do |comment|
    comment.photo.ceremony.name
  end
end
