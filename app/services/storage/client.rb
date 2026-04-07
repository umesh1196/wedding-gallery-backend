module Storage
  class Client
    def self.build
      options = {
        access_key_id:     ENV.fetch("STORAGE_ACCESS_KEY"),
        secret_access_key: ENV.fetch("STORAGE_SECRET_KEY"),
        region:            ENV.fetch("STORAGE_REGION", "us-east-1")
      }

      endpoint = ENV["STORAGE_ENDPOINT"]
      if endpoint.present?
        options[:endpoint] = endpoint
        options[:force_path_style] = ENV.fetch("STORAGE_FORCE_PATH_STYLE", "false") == "true"
      end

      Aws::S3::Client.new(options)
    end
  end
end
