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

  it "includes client_id in health record serializers by default" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    food_entry = client.food_entries.create!(
      meal_type: "lunch",
      description: "Salad",
      consumed_at: Time.zone.parse("2026-04-05 12:00:00")
    )

    serialized = FoodEntrySerializer.as_json(food_entry)

    expect(serialized).to have_key(:client_id)
    expect(serialized[:client_id]).to eq(client.id)
  end

  it "omits client_id from health record serializers with client context" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    food_entry = client.food_entries.create!(
      meal_type: "lunch",
      description: "Salad",
      consumed_at: Time.zone.parse("2026-04-05 12:00:00")
    )

    serialized = FoodEntrySerializer.as_json(food_entry, context: :client)

    expect(serialized).not_to have_key(:client_id)
    expect(serialized[:id]).to eq(food_entry.id)
  end

  it "omits client_id from collection serialization with client context" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    client.energy_logs.create!(level: 5, recorded_at: Time.zone.parse("2026-04-05 10:00:00"))

    collection = EnergyLogSerializer.collection(client.energy_logs, context: :client)

    expect(collection.first).not_to have_key(:client_id)
  end

  it "includes a minimal client payload for schedule serialization" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, focus_tag: "sleep")
    appointment = client.appointments.create!(
      practitioner: practitioner,
      scheduled_at: Time.zone.parse("2026-04-10 10:00:00"),
      duration_minutes: 45,
      appointment_type: "check_in",
      status: "scheduled"
    )

    serialized = AppointmentSerializer.as_json(appointment, context: :schedule)

    expect(serialized[:client]).to eq(
      id: client.id,
      first_name: client.first_name,
      last_name: client.last_name,
      focus_tag: "sleep"
    )
  end
end
