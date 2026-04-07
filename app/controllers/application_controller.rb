class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  rescue_from ActiveRecord::RecordNotFound,       with: :not_found
  rescue_from ActiveRecord::RecordInvalid,        with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def render_success(data, status: :ok, meta: {})
    payload = { success: true, data: data }
    payload[:meta] = meta if meta.present?
    render json: payload, status: status
  end

  def render_error(message, status:, code: nil)
    error = { message: message }
    error[:code] = code if code.present?
    render json: { success: false, error: error }, status: status
  end

  def not_found(exception)
    render_error exception.message, status: :not_found, code: "not_found"
  end

  def unprocessable_entity(exception)
    render_error exception.record.errors.full_messages.join(", "),
                 status: :unprocessable_entity,
                 code: "validation_error"
  end

  def bad_request(exception)
    render_error exception.message, status: :bad_request, code: "bad_request"
  end
end
