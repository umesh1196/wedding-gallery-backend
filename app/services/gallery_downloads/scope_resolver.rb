module GalleryDownloads
  class ScopeResolver
    def initialize(wedding:, gallery_session:, scope_type:, ceremony_slug: nil)
      @wedding = wedding
      @gallery_session = gallery_session
      @scope_type = scope_type
      @ceremony_slug = ceremony_slug
    end

    def call
      case @scope_type
      when "ceremony"
        resolve_ceremony
      when "shortlist"
        resolve_shortlist
      when "full_gallery"
        resolve_full_gallery
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
  end
end
