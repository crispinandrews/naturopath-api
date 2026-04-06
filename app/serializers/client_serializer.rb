class ClientSerializer
  def self.as_json(client, include_invite: false)
    payload = {
      id: client.id,
      email: client.email,
      first_name: client.first_name,
      last_name: client.last_name,
      date_of_birth: client.date_of_birth,
      practitioner_id: client.practitioner_id
    }

    if include_invite
      payload[:invite_token] = client.invite_token
      payload[:invite_accepted] = client.invite_accepted_at.present?
      payload[:invite_expires_at] = client.invite_expires_at
      payload[:created_at] = client.created_at
    end

    payload
  end
end
