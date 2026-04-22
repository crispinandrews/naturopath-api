class ClientSerializer
  def self.collection(records, context: nil)
    records.map { |record| as_json(record, context: context) }
  end

  def self.as_json(client, include_invite_token: false, context: nil)
    payload = {
      id: client.id,
      email: client.email,
      first_name: client.first_name,
      last_name: client.last_name,
      date_of_birth: client.date_of_birth,
      practitioner_id: client.practitioner_id,
      invite_accepted: client.invite_accepted_at.present?,
      focus_tag: client.focus_tag
    }

    payload[:invite_expires_at] = client.invite_expires_at if include_invite_expiry?(client)

    if include_invite_token
      payload[:invite_token] = client.invite_token
    end

    payload[:created_at] = client.created_at
    payload
  end

  def self.include_invite_expiry?(client)
    client.invite_accepted_at.nil? && client.invite_expires_at.present?
  end

  private_class_method :include_invite_expiry?
end
