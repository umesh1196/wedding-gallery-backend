module PhotoUploads
  module FileMetadata
    MAX_FILES_PER_REQUEST = 50
    MAX_FILE_SIZE = 30.megabytes
    ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze

    module_function

    def normalize(files_param)
      Array(files_param).first(MAX_FILES_PER_REQUEST).map do |file|
        file.respond_to?(:to_unsafe_h) ? file.to_unsafe_h.with_indifferent_access : file.to_h.with_indifferent_access
      end
    end

    def validate!(file)
      content_type = file[:content_type].to_s
      byte_size = file[:byte_size].to_i

      raise ActionController::ParameterMissing, "files" if file[:filename].blank?
      raise ArgumentError, "Unsupported file type" unless ALLOWED_CONTENT_TYPES.include?(content_type)
      raise ArgumentError, "File size must be less than 30MB" unless byte_size.positive? && byte_size <= MAX_FILE_SIZE
    end

    def extension_for(filename, content_type)
      ext = File.extname(filename.to_s).delete(".").downcase
      return ext if ext.present?

      Rack::Mime::MIME_TYPES.invert.fetch(content_type.to_s, ".jpg").delete(".")
    end
  end
end
