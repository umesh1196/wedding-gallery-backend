module Storage
  class Service
    MULTIPART_THRESHOLD = 5 * 1024 * 1024 # 5 MB

    def initialize
      @client = Storage::Client.build
      @bucket = ENV.fetch("STORAGE_BUCKET")
    end

    # Upload raw body
    def upload(key:, body:, content_type:)
      @client.put_object(
        bucket: @bucket,
        key: key,
        body: body,
        content_type: content_type
      )
    end

    # Upload a file path; uses multipart for files > 5MB
    def upload_file(key:, file_path:, content_type:)
      file_size = File.size(file_path)

      if file_size > MULTIPART_THRESHOLD
        multipart_upload(key: key, file_path: file_path, content_type: content_type)
      else
        File.open(file_path, "rb") do |f|
          upload(key: key, body: f, content_type: content_type)
        end
      end
    end

    # Download object body
    def download(key:)
      resp = @client.get_object(bucket: @bucket, key: key)
      resp.body.read
    end

    # Download to a tempfile — caller is responsible for closing/unlinking
    def download_to_tempfile(key:)
      ext = File.extname(key)
      tempfile = Tempfile.new([ "storage_download", ext ])
      tempfile.binmode

      @client.get_object(bucket: @bucket, key: key) do |chunk|
        tempfile.write(chunk)
      end

      tempfile.rewind
      tempfile
    end

    # Generate a presigned URL for client-side upload
    def presigned_upload_url(key:, content_type:, expires_in: nil)
      expires_in ||= ENV.fetch("STORAGE_PRESIGN_EXPIRY", "3600").to_i
      signer = Aws::S3::Presigner.new(client: @client)
      signer.presigned_url(
        :put_object,
        bucket: @bucket,
        key: key,
        content_type: content_type,
        expires_in: expires_in
      )
    end

    # Generate a presigned URL for client-side download
    def presigned_download_url(key:, expires_in: nil, filename: nil)
      expires_in ||= ENV.fetch("STORAGE_PRESIGN_EXPIRY", "3600").to_i
      params = { bucket: @bucket, key: key, expires_in: expires_in }
      if filename.present?
        params[:response_content_disposition] = "attachment; filename=\"#{filename}\""
      end
      signer = Aws::S3::Presigner.new(client: @client)
      signer.presigned_url(:get_object, **params)
    end

    # Construct CDN/public URL (for Imgproxy or direct access)
    def public_url(key:)
      base = ENV.fetch("STORAGE_PUBLIC_URL").chomp("/")
      "#{base}/#{key}"
    end

    def exists?(key:)
      @client.head_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    end

    def delete(key:)
      @client.delete_object(bucket: @bucket, key: key)
    end

    # Batch delete up to 1000 keys per call
    def delete_batch(keys:)
      return if keys.empty?

      keys.each_slice(1000) do |batch|
        objects = batch.map { |k| { key: k } }
        @client.delete_objects(
          bucket: @bucket,
          delete: { objects: objects, quiet: true }
        )
      end
    end

    def list(prefix:, max_keys: 1000)
      resp = @client.list_objects_v2(bucket: @bucket, prefix: prefix, max_keys: max_keys)
      resp.contents.map(&:key)
    end

    # Copy object (useful for migrations)
    def copy(source_key:, destination_key:)
      @client.copy_object(
        bucket: @bucket,
        copy_source: "#{@bucket}/#{source_key}",
        key: destination_key
      )
    end

    private

    def multipart_upload(key:, file_path:, content_type:)
      resp = @client.create_multipart_upload(
        bucket: @bucket,
        key: key,
        content_type: content_type
      )
      upload_id = resp.upload_id
      parts = []

      begin
        File.open(file_path, "rb") do |file|
          part_number = 1
          until file.eof?
            chunk = file.read(MULTIPART_THRESHOLD)
            part_resp = @client.upload_part(
              bucket: @bucket,
              key: key,
              upload_id: upload_id,
              part_number: part_number,
              body: chunk
            )
            parts << { part_number: part_number, etag: part_resp.etag }
            part_number += 1
          end
        end

        @client.complete_multipart_upload(
          bucket: @bucket,
          key: key,
          upload_id: upload_id,
          multipart_upload: { parts: parts }
        )
      rescue => e
        @client.abort_multipart_upload(bucket: @bucket, key: key, upload_id: upload_id)
        raise e
      end
    end
  end
end
