module Gallery
  class PhotoPayloadBuilder
    def initialize(photo:, liked_photo_ids: Set.new, shortlisted_photo_ids: Set.new)
      @photo = photo
      @liked_photo_ids = liked_photo_ids
      @shortlisted_photo_ids = shortlisted_photo_ids
    end

    def call
      urls = PhotoUrlBuilder.new(@photo).urls

      {
        id: @photo.id,
        thumbnail_url: urls[:thumbnail],
        preview_url: urls[:preview],
        blur_hash: urls[:blur],
        width: @photo.width,
        height: @photo.height,
        comment_count: @photo.comments_count,
        is_liked: @liked_photo_ids.include?(@photo.id),
        is_shortlisted: @shortlisted_photo_ids.include?(@photo.id)
      }
    end
  end
end
