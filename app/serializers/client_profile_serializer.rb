class ClientProfileSerializer
  def self.collection(records)
    records.map { |record| as_json(record) }
  end

  def self.as_json(client)
    {
      id: client.id,
      email: client.email,
      first_name: client.first_name,
      last_name: client.last_name,
      date_of_birth: client.date_of_birth,
      practitioner: {
        id: client.practitioner.id,
        first_name: client.practitioner.first_name,
        last_name: client.practitioner.last_name,
        practice_name: client.practitioner.practice_name
      }
    }
  end
end
