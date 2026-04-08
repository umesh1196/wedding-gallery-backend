module PhotoSources
  class Error < StandardError; end

  def self.build(connection)
    case connection.provider
    when "cloudflare_r2", "backblaze_b2"
      S3Compatible.new(connection)
    else
      raise Error, "Unsupported source provider"
    end
  end
end
