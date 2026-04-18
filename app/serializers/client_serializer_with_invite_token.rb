class ClientSerializerWithInviteToken
  def self.collection(records, context: nil)
    records.map { |record| as_json(record, context: context) }
  end

  def self.as_json(client, context: nil)
    ClientSerializer.as_json(client, include_invite_token: true, context: context)
  end
end
