module Storage
  module KeyBuilder
    def self.original(studio_id:, wedding_id:, photo_id:, ext:)
      "studios/#{studio_id}/weddings/#{wedding_id}/photos/#{photo_id}/original.#{ext}"
    end

    def self.thumbnail(studio_id:, wedding_id:, photo_id:)
      "studios/#{studio_id}/weddings/#{wedding_id}/photos/#{photo_id}/thumbnail.jpg"
    end

    def self.hero(studio_id:, wedding_id:)
      "studios/#{studio_id}/weddings/#{wedding_id}/hero.jpg"
    end

    def self.ceremony_cover(studio_id:, wedding_id:, ceremony_id:)
      "studios/#{studio_id}/weddings/#{wedding_id}/ceremonies/#{ceremony_id}/cover.jpg"
    end

    def self.studio_logo(studio_id:, ext: "jpg")
      "studios/#{studio_id}/logo.#{ext}"
    end

    def self.studio_watermark(studio_id:, ext: "jpg")
      "studios/#{studio_id}/watermark.#{ext}"
    end

    def self.wedding_prefix(studio_id:, wedding_id:)
      "studios/#{studio_id}/weddings/#{wedding_id}/"
    end
  end
end
