module PhotoSources
  class Base
    def initialize(connection)
      @connection = connection
    end

    def list(prefix:)
      raise NotImplementedError
    end

    def head(key:)
      raise NotImplementedError
    end

    def stream_to_tempfile(key:)
      raise NotImplementedError
    end

    def supports_server_side_copy_to_gallery_storage?
      false
    end
  end
end
