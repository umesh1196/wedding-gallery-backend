module PhotoImports
  class DiscoverService
    def initialize(connection:, prefix:)
      @connection = connection
      @prefix = prefix
    end

    def call
      source = PhotoSources.build(@connection)
      normalized_prefix = @connection.normalized_prefix(@prefix)

      {
        connection_id: @connection.id,
        provider: @connection.provider,
        bucket: @connection.bucket,
        prefix: normalized_prefix,
        files: source.list(prefix: normalized_prefix)
      }
    end
  end
end
