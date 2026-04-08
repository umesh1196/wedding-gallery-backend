class RequestLoggingMiddleware
  def initialize(app, logger: Rails.logger)
    @app = app
    @logger = logger
  end

  def call(env)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)

    @logger.info(
      [
        "request_id=#{env["action_dispatch.request_id"] || "unknown"}",
        "method=#{env["REQUEST_METHOD"]}",
        "path=#{env["PATH_INFO"]}",
        "status=#{status}",
        format("duration_ms=%.2f", elapsed_ms(started_at))
      ].join(" ")
    )

    [ status, headers, body ]
  end

  private

  def elapsed_ms(started_at)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0
  end
end
