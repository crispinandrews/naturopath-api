module AuthHeaders
  def auth_headers_for(user)
    token = JwtService.encode({ user_id: user.id, user_type: user.class.name })
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHeaders, type: :request
end
