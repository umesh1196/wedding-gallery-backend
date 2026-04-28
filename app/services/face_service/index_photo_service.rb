require "net/http"
require "json"
require "uri"

module FaceService
  class IndexPhotoService
    FACE_SERVICE_URL = ENV.fetch("FACE_SERVICE_URL", "http://localhost:8001")
    THRESHOLD = ENV.fetch("FACE_THRESHOLD", "0.40").to_f

    def initialize(photo)
      @photo = photo
    end

    def call
      # Step 1: ask the face service to extract embeddings from this image
      image_url = PhotoUrlBuilder.new(@photo).urls[:preview] ||
                  Storage::Service.new.presigned_download_url(key: @photo.original_key)

      faces = extract_embeddings(image_url)

      if faces.empty?
        @photo.update_columns(
          face_recognition_status: "skipped",
          face_recognition_error: nil,
          face_recognized_at: Time.current
        )
        return
      end

      # Step 2: for each face, ask the face service who is nearest in this wedding
      #         (using wedding_id as the namespace — face service doesn't know what that means)
      namespace = @photo.wedding_id.to_s
      assignments = assign_persons(faces, namespace)

      if assignments.empty?
        @photo.update_columns(
          face_recognition_status: "skipped",
          face_recognition_error: nil,
          face_recognized_at: Time.current
        )
        return
      end

      # Step 3: persist embeddings only for person-photo pairs not yet stored (idempotency)
      new_assignments = assignments.reject do |a|
        PersonPhoto.exists?(person_id: a[:person_id], photo_id: @photo.id)
      end
      store_vectors(namespace, new_assignments) if new_assignments.any?

      # Step 4: Rails records which person appears in which photo
      assignments.each do |a|
        PersonPhoto.find_or_create_by!(person_id: a[:person_id], photo_id: @photo.id)
      end

      @photo.update_columns(
        face_recognition_status: "done",
        face_recognition_error: nil,
        face_recognized_at: Time.current
      )
      # Errors propagate to FaceIndexJob which handles per-photo failure tracking
    end

    private

    def extract_embeddings(image_url)
      uri = URI.parse("#{FACE_SERVICE_URL}/extract")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 30
      req = Net::HTTP::Post.new(uri.path, default_headers.merge("X-Image-Url" => image_url))
      resp = http.request(req)
      JSON.parse(resp.body, symbolize_names: true)[:faces] || []
    end

    def assign_persons(faces, namespace)
      faces.map do |face|
        # Ask face service: which stored id is nearest to this embedding?
        nearest = find_nearest(namespace, face[:embedding])

        person = if nearest && nearest[:distance].to_f <= THRESHOLD
          # Face service returned an opaque id — Rails knows it's a person_id
          Person.find_by(id: nearest[:id]) ||
            create_anonymous_person
        else
          create_anonymous_person
        end

        {
          person_id: person.id,
          face_index: face[:face_index],
          embedding: face[:embedding],
          confidence: face[:confidence],
          bbox: face[:bbox]
        }
      end
    end

    def find_nearest(namespace, embedding)
      resp = post("/find-similar", {
        namespace: namespace,
        embedding: embedding,
        threshold: THRESHOLD,
        limit: 1
      })
      data = JSON.parse(resp.body, symbolize_names: true)
      data[:matches]&.first
    end

    def store_vectors(namespace, assignments)
      vectors = assignments.map do |a|
        {
          id: a[:person_id].to_s,       # opaque to face service — it's a person_id to us
          embedding: a[:embedding],
          metadata: {                    # opaque to face service — useful for debugging
            face_index: a[:face_index],
            confidence: a[:confidence],
            bbox: a[:bbox],
            photo_id: @photo.id.to_s
          }
        }
      end

      post("/store-batch", { namespace: namespace, vectors: vectors })
    end

    def create_anonymous_person
      Person.create!(
        wedding_id: @photo.wedding_id,
        label: "Person #{SecureRandom.hex(3)}",
        is_known: false
      )
    end

    def get(path, headers: {})
      uri = URI.parse("#{FACE_SERVICE_URL}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 30
      req = Net::HTTP::Get.new(uri.path, default_headers.merge(headers))
      http.request(req)
    end

    def post(path, body)
      uri = URI.parse("#{FACE_SERVICE_URL}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 30
      req = Net::HTTP::Post.new(uri.path, default_headers.merge("Content-Type" => "application/json"))
      req.body = body.to_json
      http.request(req)
    end

    def default_headers
      { "X-Internal-Secret" => ENV.fetch("FACE_SERVICE_SECRET", "") }
    end
  end
end
