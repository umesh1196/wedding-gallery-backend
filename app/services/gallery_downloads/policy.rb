module GalleryDownloads
  class Policy
    def initialize(wedding:, gallery_session:)
      @wedding = wedding
      @gallery_session = gallery_session
    end

    def allow_single_photo?(photo)
      case @wedding.allow_download
      when "all"
        true
      when "shortlist"
        shortlisted_photo_ids.include?(photo.id)
      else
        false
      end
    end

    def allow_bulk_scope?(scope_type, photo_ids: [])
      case @wedding.allow_download
      when "all"
        scope_type != "selected_photos" || photo_ids.present?
      when "shortlist"
        return scope_type == "shortlist" && shortlist.present? && shortlist.shortlist_photos.exists? if scope_type != "selected_photos"

        photo_ids.present? && (photo_ids - shortlisted_photo_ids.to_a).empty?
      else
        false
      end
    end

    def shortlist
      @shortlist ||= Shortlist.find_by(wedding: @wedding, gallery_session: @gallery_session)
    end

    private

    def shortlisted_photo_ids
      @shortlisted_photo_ids ||= shortlist ? shortlist.shortlist_photos.pluck(:photo_id).to_set : Set.new
    end
  end
end
