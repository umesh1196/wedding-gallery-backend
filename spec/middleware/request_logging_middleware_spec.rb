require "rails_helper"

RSpec.describe RequestLoggingMiddleware do
  let(:app) { ->(_env) { [ 200, { "Content-Type" => "application/json" }, [ "{\"status\":\"ok\"}" ] ] } }
  let(:logger) { instance_double(Logger, info: true) }
  let(:middleware) { described_class.new(app, logger: logger) }

  it "logs method, path, status, and duration" do
    env = Rack::MockRequest.env_for("/health", "REQUEST_METHOD" => "GET")
    env["action_dispatch.request_id"] = "req-123"

    middleware.call(env)

    expect(logger).to have_received(:info).with(
      a_string_including(
        "request_id=req-123",
        "method=GET",
        "path=/health",
        "status=200",
        "duration_ms="
      )
    )
  end
end
