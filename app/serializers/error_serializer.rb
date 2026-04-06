class ErrorSerializer
  def self.as_json(code:, message:, request_id:, details: nil, meta: nil)
    payload = {
      code: code,
      message: message,
      request_id: request_id
    }
    payload[:details] = details if details.present?
    payload[:meta] = meta if meta.present?

    { error: payload }
  end
end
