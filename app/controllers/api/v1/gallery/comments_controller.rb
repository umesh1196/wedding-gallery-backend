module Api
  module V1
    module Gallery
      class CommentsController < BaseController
        DEFAULT_LIMIT = 50
        MAX_LIMIT = 100

        before_action :ensure_comments_allowed!

        def index
          comments = photo.comments.newest_first.limit(limit)
          render_success(CommentBlueprint.render_as_hash(comments))
        end

        def create
          limiter = ::Gallery::CommentRateLimiter.new(
            wedding: current_wedding,
            gallery_session: current_gallery_session,
            ip: request.remote_ip
          )

          unless limiter.allowed?
            return render_error("Too many comment attempts", status: :too_many_requests, code: "rate_limited")
          end

          comment = photo.comments.build(comment_params)
          comment.gallery_session = current_gallery_session
          comment.save!
          limiter.record!

          render_success(CommentBlueprint.render_as_hash(comment), status: :created)
        end

        def destroy
          render_success({ id: comment.id, deleted: true }) if comment.destroy
        end

        private

        def ensure_comments_allowed!
          return if current_wedding.allow_comments?

          render_error("Comments are disabled for this gallery", status: :forbidden, code: "comments_disabled")
        end

        def photo
          @photo ||= current_wedding.photos.ready.find(params[:photo_id])
        end

        def comment
          @comment ||= current_gallery_session.comments.joins(:photo).where(photos: { wedding_id: current_wedding.id }).find(params[:id])
        end

        def comment_params
          params.require(:comment).permit(:body)
        end

        def limit
          requested = params[:limit].to_i
          return DEFAULT_LIMIT if requested <= 0

          [ requested, MAX_LIMIT ].min
        end
      end
    end
  end
end
