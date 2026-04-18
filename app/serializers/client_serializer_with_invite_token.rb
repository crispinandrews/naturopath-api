class ClientSerializerWithInviteToken
  def self.collection(records)
    records.map { |record| as_json(record) }
  end

  def self.as_json(client)
    ClientSerializer.as_json(client, include_invite_token: true)
  end
end
