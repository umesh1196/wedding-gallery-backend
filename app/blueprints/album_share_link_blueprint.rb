class AlbumShareLinkBlueprint < Blueprinter::Base
  identifier :id

  fields :permissions, :label, :expires_at
end
