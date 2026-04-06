class PractitionerSerializer
  def self.as_json(practitioner)
    {
      id: practitioner.id,
      email: practitioner.email,
      first_name: practitioner.first_name,
      last_name: practitioner.last_name,
      practice_name: practitioner.practice_name
    }
  end
end
