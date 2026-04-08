class AlbumBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :slug, :description, :album_type, :visibility, :photos_count

  field :cover_photo_id do |album|
    album.cover_photo_id
  end
end
