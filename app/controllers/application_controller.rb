class ApplicationController < ActionController::API
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
    return nil unless token

    payload = JwtService.decode(token)
    return nil unless payload && payload[:user_type] == klass.name

    klass.find_by(id: payload[:user_id])
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def render_not_found
    render json: { error: "Not found" }, status: :not_found
  end

  def render_validation_errors(record)
    render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
  end
end
