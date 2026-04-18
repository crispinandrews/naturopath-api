class ApplicationController < ActionController::API
  class InvalidDateFilterError < StandardError; end
  class InvalidPaginationError < StandardError; end

  rescue_from InvalidDateFilterError, with: :render_invalid_date_filter
  rescue_from InvalidPaginationError, with: :render_invalid_pagination
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from StandardError, with: :render_internal_server_error unless Rails.env.development? || Rails.env.test?

  private

  def authenticate_practitioner!
    @current_practitioner = authenticate_user(::Practitioner)
    render_unauthorized unless @current_practitioner
  end

  def authenticate_client!
    @current_client = authenticate_user(::Client)
    render_unauthorized unless @current_client
  end

  def authenticate_user(klass)
    token = extract_token
    return authentication_failure!(:missing_token) unless token

    result = JwtService.decode(token)
    return authentication_failure!(result[:error]) unless result[:payload]

    payload = result[:payload]
    return authentication_failure!(:invalid_token) unless payload[:user_type] == klass.name

    user = klass.find_by(id: payload[:user_id])
    return authentication_failure!(:user_not_found) unless user

    @authentication_failure_reason = nil
    user
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized
    AppEventLogger.warn("auth.unauthorized", **request_context(reason: @authentication_failure_reason))
    render_error(code: "unauthorized", message: "Unauthorized", status: :unauthorized)
  end

  def render_not_found(_exception = nil)
    render_error(code: "not_found", message: "Not found", status: :not_found)
  end

  def render_validation_errors(record)
    render_error(
      code: "validation_failed",
      message: "Validation failed",
      status: :unprocessable_entity,
      details: record.errors.full_messages
    )
  end

  def render_invalid_date_filter(error)
    render_error(
      code: "invalid_date_filter",
      message: error.message,
      status: :unprocessable_entity
    )
  end

  def render_invalid_pagination(error)
    render_error(
      code: "invalid_pagination",
      message: error.message,
      status: :unprocessable_entity
    )
  end

  def render_parameter_missing(error)
    render_error(
      code: "parameter_missing",
      message: error.message,
      status: :bad_request
    )
  end

  def render_internal_server_error(exception)
    ExceptionReporter.report(exception, context: request_context(actor_context))
    render_error(
      code: "internal_server_error",
      message: "Internal server error",
      status: :internal_server_error
    )
  end

  def render_error(code:, message:, status:, details: nil, meta: nil)
    render json: ErrorSerializer.as_json(
      code: code,
      message: message,
      request_id: request.request_id,
      details: details,
      meta: meta
    ), status: status
  end

  def render_resource(record, serializer:, status: :ok, meta: nil)
    render json: {
      data: serializer.as_json(record, context: serializer_context),
      meta: meta
    }.compact, status: status
  end

  def render_collection(records, serializer:, meta: {})
    render json: {
      data: serializer.collection(records, context: serializer_context),
      meta: meta
    }, status: :ok
  end

  def serializer_context
    nil
  end

  def request_context(extra_context = {})
    {
      request_id: request.request_id,
      method: request.request_method,
      path: request.fullpath,
      remote_ip: request.remote_ip,
      controller: controller_name,
      action: action_name
    }.merge(extra_context).compact
  end

  def actor_context
    return { practitioner_id: @current_practitioner.id } if defined?(@current_practitioner) && @current_practitioner.present?
    return { client_id: @current_client.id } if defined?(@current_client) && @current_client.present?

    {}
  end

  def authentication_failure!(reason)
    @authentication_failure_reason = reason
    nil
  end
end
