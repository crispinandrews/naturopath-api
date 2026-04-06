module RequestHelpers
  def unique_email(prefix = "user")
    "#{prefix}-#{SecureRandom.hex(6)}@example.com"
  end

  def create_practitioner(**attrs)
    Practitioner.create!({
      email: unique_email("practitioner"),
      password: "password123",
      first_name: "Pat",
      last_name: "Doctor",
      practice_name: "Wellness Practice"
    }.merge(attrs))
  end

  def create_client(practitioner:, accepted: true, **attrs)
    defaults = {
      email: unique_email("client"),
      first_name: "Casey",
      last_name: "Patient"
    }

    if accepted
      invite_accepted_at = attrs.delete(:invite_accepted_at) || Time.current
      password = attrs.delete(:password) || "password123"
      client = practitioner.clients.create!(defaults.merge(attrs).merge(
        password: password,
        invite_accepted_at: invite_accepted_at
      ))
      client.update_columns(invite_token: nil)
      client
    else
      practitioner.clients.create!(defaults.merge(attrs))
    end
  end

  def json_response
    response.parsed_body
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
