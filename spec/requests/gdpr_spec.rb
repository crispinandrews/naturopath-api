require "rails_helper"

RSpec.describe "GDPR endpoints", type: :request do
  before do
    @practitioner = create_practitioner
    @client = create_client(practitioner: @practitioner)
    @client.food_entries.create!(description: "Breakfast", consumed_at: Time.zone.parse("2026-04-05 09:00:00"))
    @client.symptoms.create!(name: "Bloating", occurred_at: Time.zone.parse("2026-04-05 10:00:00"))
    @client.energy_logs.create!(level: 6, recorded_at: Time.zone.parse("2026-04-05 11:00:00"))
    @client.sleep_logs.create!(
      bedtime: Time.zone.parse("2026-04-04 23:00:00"),
      wake_time: Time.zone.parse("2026-04-05 07:00:00"),
      quality: 7
    )
    @client.water_intakes.create!(amount_ml: 500, recorded_at: Time.zone.parse("2026-04-05 12:00:00"))
    @client.supplements.create!(name: "Vitamin D", taken_at: Time.zone.parse("2026-04-05 08:00:00"))
    @client.consents.create!(
      consent_type: "health_data_processing",
      version: "1.0",
      granted_at: Time.current,
      ip_address: "127.0.0.1"
    )
  end

  it "requires client authentication for export" do
    post "/api/v1/gdpr/export"

    expect(response).to have_http_status(:unauthorized)
    expect(json_response).to eq({ "error" => "Unauthorized" })
  end

  it "exports the client's profile and health data" do
    post "/api/v1/gdpr/export", headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(json_response["data"]["profile"]["email"]).to eq(@client.email)
    expect(json_response["data"]["food_entries"].size).to eq(1)
    expect(json_response["data"]["symptoms"].size).to eq(1)
    expect(json_response["data"]["energy_logs"].size).to eq(1)
    expect(json_response["data"]["sleep_logs"].size).to eq(1)
    expect(json_response["data"]["water_intakes"].size).to eq(1)
    expect(json_response["data"]["supplements"].size).to eq(1)
    expect(json_response["data"]["consents"].size).to eq(1)
  end

  it "deletes health data and keeps consent history" do
    delete "/api/v1/gdpr/delete", headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(json_response["message"]).to eq("All health data has been deleted")
    expect(@client.food_entries.count).to eq(0)
    expect(@client.symptoms.count).to eq(0)
    expect(@client.energy_logs.count).to eq(0)
    expect(@client.sleep_logs.count).to eq(0)
    expect(@client.water_intakes.count).to eq(0)
    expect(@client.supplements.count).to eq(0)
    expect(@client.consents.where(consent_type: "health_data_processing").count).to eq(1)
    expect(@client.consents.where(consent_type: "data_deletion_request").count).to eq(1)
  end

  it "rolls back deletions if the audit consent cannot be saved" do
    invalid_consent = Consent.new
    invalid_consent.validate
    allow_any_instance_of(Consent).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(invalid_consent))

    delete "/api/v1/gdpr/delete", headers: auth_headers_for(@client)

    expect(response).to have_http_status(422)
    expect(json_response["errors"]).not_to be_empty
    expect(@client.food_entries.count).to eq(1)
    expect(@client.symptoms.count).to eq(1)
    expect(@client.energy_logs.count).to eq(1)
    expect(@client.sleep_logs.count).to eq(1)
    expect(@client.water_intakes.count).to eq(1)
    expect(@client.supplements.count).to eq(1)
    expect(@client.consents.where(consent_type: "data_deletion_request").count).to eq(0)
  end
end
