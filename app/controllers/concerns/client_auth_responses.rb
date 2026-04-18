module ClientAuthResponses
  extend ActiveSupport::Concern

  private

  def render_auth_success(client, refresh_token: nil)
    render json: client_auth_payload(client, refresh_token: refresh_token)
  end

  def client_auth_payload(client, refresh_token: nil)
    {
      token: JwtService.encode({ user_id: client.id, user_type: "Client" }),
      refresh_token: refresh_token || ::RefreshToken.issue_for!(client)[:plaintext_token],
      client: ClientSerializer.as_json(client)
    }
  end
end
