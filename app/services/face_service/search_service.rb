require "net/http"
require "json"
require "uri"

module FaceService
  class SearchService
    FACE_SERVICE_URL = ENV.fetch("FACE_SERVICE_URL", "http://localhost:8001")

    def initialize(wedding_id:, selfie_file:, threshold: 0.40)
      @wedding_id = wedding_id
      @selfie_file = selfie_file
      @threshold = threshold
    end

    def call
      resp = post_multipart
      data = JSON.parse(resp.body, symbolize_names: true)

      # nearest_id is an opaque id from the face service — Rails knows it's a person_id
      nearest_id = data[:nearest_id]
      person = nearest_id ? Person.find_by(id: nearest_id) : nil
      photo_ids = person ? person.person_photos.pluck(:photo_id) : []

      {
        photo_ids: photo_ids,
        person: person ? { id: person.id, label: person.label, avatar_url: person.avatar_url } : nil
      }
    rescue StandardError => e
      Rails.logger.error("[FaceService] Search failed: #{e.message}")
      { photo_ids: [], person: nil }
    end

    private

    def post_multipart
      uri = URI.parse("#{FACE_SERVICE_URL}/find-similar-in-image")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 30

      boundary = SecureRandom.hex(16)
      body = build_multipart_body(boundary)

      req = Net::HTTP::Post.new(uri.path, {
        "Content-Type"      => "multipart/form-data; boundary=#{boundary}",
        "X-Internal-Secret" => ENV.fetch("FACE_SERVICE_SECRET", ""),
        "X-Namespace"       => @wedding_id.to_s,
        "X-Threshold"       => @threshold.to_s
      })
      req.body = body
      http.request(req)
    end

    def build_multipart_body(boundary)
      filename     = @selfie_file.original_filename.presence || "selfie.jpg"
      content_type = @selfie_file.content_type.presence || "image/jpeg"
      file_data    = @selfie_file.tempfile.read

      "--#{boundary}\r\n" \
      "Content-Disposition: form-data; name=\"image\"; filename=\"#{filename}\"\r\n" \
      "Content-Type: #{content_type}\r\n\r\n" \
      "#{file_data}\r\n" \
      "--#{boundary}--\r\n"
    end
  end
end
