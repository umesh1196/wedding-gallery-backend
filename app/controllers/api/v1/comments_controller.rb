module Api
  module V1
    class CommentsController < BaseController
      DEFAULT_LIMIT = 100
      MAX_LIMIT = 200

      def index
        comments = wedding.comments.includes(photo: :ceremony).newest_first.limit(limit)
        render_success(StudioCommentBlueprint.render_as_hash(comments))
      end

      private

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:wedding_slug] || params[:slug])
      end

      def limit
        requested = params[:limit].to_i
        return DEFAULT_LIMIT if requested <= 0

        [ requested, MAX_LIMIT ].min
      end
    end
  end
end
