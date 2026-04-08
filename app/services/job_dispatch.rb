class JobDispatch
  class << self
    def enqueue(job_class, *args)
      job_class.perform_later(*args)
    rescue StandardError => e
      raise e unless fallback_environment?
      raise e unless enqueue_backend_error?(e)

      job_class.perform_now(*args)
    end

    private

    def fallback_environment?
      Rails.env.development? || Rails.env.test?
    end

    def enqueue_backend_error?(error)
      error.is_a?(ActiveRecord::StatementInvalid) ||
        (defined?(SolidQueue::Job::EnqueueError) && error.is_a?(SolidQueue::Job::EnqueueError))
    end
  end
end
