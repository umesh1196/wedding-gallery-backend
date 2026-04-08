class PhotoBlueprint < Blueprinter::Base
  identifier :id

  fields :original_filename, :file_extension, :width, :height, :aspect_ratio,
         :sort_order, :is_cover, :ingestion_status, :processing_status

  field :urls do |photo|
    photo.processing_status == "ready" ? photo.urls : {}
  end
end
