module GalleryDownloads
  class ScopeResolver
    def initialize(wedding:, gallery_session:, scope_type:, ceremony_slug: nil, photo_ids: [])
      @wedding = wedding
      @gallery_session = gallery_session
      @scope_type = scope_type
      @ceremony_slug = ceremony_slug
      @photo_ids = Array(photo_ids).map(&:to_s)
    end

    def call
      case @scope_type
      when "ceremony"
        resolve_ceremony
      when "shortlist"
        resolve_shortlist
      when "full_gallery"
        resolve_full_gallery
      when "selected_photos"
        resolve_selected_photos
      else
        raise ArgumentError, "Unsupported download scope"
      end
    end

    private

    def resolve_ceremony
      ceremony = @wedding.ceremonies.find_by!(slug: @ceremony_slug)
      photos = ceremony.photos.ready.order(:sort_order, :id).to_a

      {
        ceremony: ceremony,
        shortlist: nil,
        photos: photos,
        filename: "#{@wedding.slug}-#{ceremony.slug}.zip"
      }
    end

    def resolve_shortlist
      shortlist = Shortlist.find_by!(wedding: @wedding, gallery_session: @gallery_session)
      photos = shortlist.shortlist_photos.includes(:photo).order(:sort_order, :id).map(&:photo)

      {
        ceremony: nil,
        shortlist: shortlist,
        photos: photos,
        filename: "#{@wedding.slug}-shortlist.zip"
      }
    end

    def resolve_full_gallery
      {
        ceremony: nil,
        shortlist: nil,
        photos: @wedding.photos.ready.order(:sort_order, :id).to_a,
        filename: "#{@wedding.slug}-gallery.zip"
      }
    end

    def resolve_selected_photos
      photos = @wedding.photos.ready.where(id: @photo_ids).order(:sort_order, :id).to_a
      missing_ids = @photo_ids - photos.map(&:id)
      raise ActiveRecord::RecordNotFound, "Couldn't find selected photos" if missing_ids.any?

      {
        ceremony: nil,
        shortlist: nil,
        photos: photos,
        filename: "#{@wedding.slug}-selected-photos.zip"
      }
    end
  end
end
