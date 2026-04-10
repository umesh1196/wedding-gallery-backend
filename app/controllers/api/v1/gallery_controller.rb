module Api
  module V1
    class GalleryController < ApplicationController
      def verify
        return rate_limited! if verify_rate_limiter.rate_limited?
        return render_error("Gallery expired", status: :gone, code: "gallery_expired") if wedding.expired?

        unless wedding.authenticate(params.require(:password))
          verify_rate_limiter.increment_failures!
          return render_error("Unauthorized", status: :unauthorized, code: "unauthorized")
        end

        verify_rate_limiter.reset!
        guest_identity, issued_guest_identity_token = resolved_guest_identity
        _session, token = GallerySession.issue_for!(
          wedding: wedding,
          visitor_name: params[:visitor_name].presence,
          guest_identity: guest_identity,
          ip: request.remote_ip,
          user_agent: request.user_agent
        )

        render_success(
          {
            session_token: token,
            guest_identity_token: issued_guest_identity_token || params[:guest_identity_token].presence,
            gallery: gallery_payload(wedding)
          }
        )
      end

      def show
        render_success(gallery_payload(current_wedding))
      end

      private

      def wedding
        @wedding ||= Wedding.joins(:studio).find_by!(
          slug: params[:wedding_slug],
          studios: { slug: params[:studio_slug] }
        )
      end

      def gallery_payload(record)
        ::Gallery::PayloadBuilder.new(wedding: record).call
      end

      def rate_limited!
        response.set_header("Retry-After", verify_rate_limiter.retry_after.to_s)
        render_error("Too many verification attempts", status: :too_many_requests, code: "rate_limited")
      end

      def verify_rate_limiter
        @verify_rate_limiter ||= ::Gallery::VerifyRateLimiter.new(
          studio_slug: params[:studio_slug],
          wedding_slug: params[:wedding_slug],
          ip: request.remote_ip
        )
      end

      def resolved_guest_identity
        existing = GuestIdentity.find_for_token(params[:guest_identity_token], wedding: wedding)
        return [ existing, nil ] if existing.present?

        GuestIdentity.issue_for!(wedding: wedding, visitor_name: params[:visitor_name].presence)
      end
    end
  end
end
