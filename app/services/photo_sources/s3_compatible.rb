module PhotoSources
  class S3Compatible < Base
    def list(prefix:)
      client.list_objects_v2(bucket: @connection.bucket, prefix: prefix, max_keys: 1000).contents.filter_map do |item|
        next unless supported_key?(item.key)

        {
          source_key: item.key,
          filename: File.basename(item.key),
          content_type: content_type_for(item.key),
          byte_size: item.size,
          etag: item.etag.to_s.delete('"')
        }
      end
    end

    def head(key:)
      resp = client.head_object(bucket: @connection.bucket, key: key)
      {
        content_type: resp.content_type,
        byte_size: resp.content_length,
        etag: resp.etag.to_s.delete('"'),
        filename: File.basename(key)
      }
    end

    def stream_to_tempfile(key:)
      ext = File.extname(key)
      tempfile = Tempfile.new([ "photo_source", ext ])
      tempfile.binmode

      client.get_object(bucket: @connection.bucket, key: key) do |chunk|
        tempfile.write(chunk)
      end

      tempfile.rewind
      tempfile
    end

    private

    def client
      @client ||= Aws::S3::Client.new(
        access_key_id: @connection.credentials[:access_key_id],
        secret_access_key: @connection.credentials[:secret_access_key],
        endpoint: @connection.endpoint.presence,
        region: @connection.region.presence || "auto",
        force_path_style: true
      )
    end

    def supported_key?(key)
      %w[.jpg .jpeg .png .webp .heic].include?(File.extname(key).downcase)
    end

    def content_type_for(key)
      Marcel::MimeType.for(name: key)
    end
  end
end
