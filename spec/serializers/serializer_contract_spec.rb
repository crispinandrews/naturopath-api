require "rails_helper"

RSpec.describe "Serializer contracts" do
  include RequestHelpers

  it "returns symbol-keyed hashes for record serializers" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    food_entry = client.food_entries.create!(
      meal_type: "breakfast",
      description: "Oats",
      consumed_at: Time.zone.parse("2026-04-05 09:00:00")
    )

    serialized_food_entry = FoodEntrySerializer.as_json(food_entry)
    serialized_client = ClientSerializer.as_json(client)
    serialized_practitioner = PractitionerSerializer.as_json(practitioner)

    expect(serialized_food_entry.keys).to all(be_a(Symbol))
    expect(serialized_client.keys).to all(be_a(Symbol))
    expect(serialized_practitioner.keys).to all(be_a(Symbol))
  end

  it "omits invite_expires_at for accepted clients" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    serialized_client = ClientSerializer.as_json(client)

    expect(serialized_client[:invite_accepted]).to be(true)
    expect(serialized_client).not_to have_key(:invite_expires_at)
  end

  it "includes invite_expires_at for pending clients" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, accepted: false)

    serialized_client = ClientSerializer.as_json(client)

    expect(serialized_client[:invite_accepted]).to be(false)
    expect(serialized_client[:invite_expires_at]).to be_present
  end

  it "supports collection serialization for client profiles" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    expect(ClientProfileSerializer.collection([ client ])).to eq([ ClientProfileSerializer.as_json(client) ])
  end
end
