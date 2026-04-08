class CommentBlueprint < Blueprinter::Base
  identifier :id

  fields :body, :created_at

  field :visitor_name do |comment|
    comment.visitor_name_snapshot
  end
end
