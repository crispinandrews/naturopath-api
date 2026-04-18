require "rails_helper"

RSpec.describe "Health record endpoints", type: :request do
  RESOURCE_CONFIG = {
    food_entries: {
      model: FoodEntry,
      association: :food_entries,
      valid_attrs: -> {
        {
          meal_type: "breakfast",
          description: "Oats and berries",
          consumed_at: Time.zone.parse("2026-04-05 09:00:00"),
          notes: "Felt fine"
        }
      },
      update_attrs: -> { { notes: "Updated meal note" } },
      invalid_attrs: -> { { consumed_at: nil } }
    },
    symptoms: {
      model: Symptom,
      association: :symptoms,
      valid_attrs: -> {
        {
          name: "Headache",
          severity: 4,
          occurred_at: Time.zone.parse("2026-04-05 10:00:00"),
          duration_minutes: 30,
          notes: "Mild"
        }
      },
      update_attrs: -> { { severity: 7, notes: "Worse later" } },
      invalid_attrs: -> { { name: nil } }
    },
    energy_logs: {
      model: EnergyLog,
      association: :energy_logs,
      valid_attrs: -> {
        {
          level: 6,
          recorded_at: Time.zone.parse("2026-04-05 11:00:00"),
          notes: "Steady"
        }
      },
      update_attrs: -> { { level: 8, notes: "Improved" } },
      invalid_attrs: -> { { level: nil } }
    },
    sleep_logs: {
      model: SleepLog,
      association: :sleep_logs,
      valid_attrs: -> {
        {
          bedtime: Time.zone.parse("2026-04-04 22:30:00"),
          wake_time: Time.zone.parse("2026-04-05 06:30:00"),
          quality: 7,
          hours_slept: 8.0,
          notes: "Solid sleep"
        }
      },
      update_attrs: -> { { quality: 9, notes: "Best sleep this week" } },
      invalid_attrs: -> { { bedtime: nil } }
    },
    water_intakes: {
      model: WaterIntake,
      association: :water_intakes,
      valid_attrs: -> {
        {
          amount_ml: 500,
          recorded_at: Time.zone.parse("2026-04-05 12:00:00")
        }
      },
      update_attrs: -> { { amount_ml: 750 } },
      invalid_attrs: -> { { amount_ml: 0 } }
    },
    supplements: {
      model: Supplement,
      association: :supplements,
      valid_attrs: -> {
        {
          name: "Magnesium",
          dosage: "250mg",
          taken_at: Time.zone.parse("2026-04-05 08:00:00"),
          notes: "With breakfast"
        }
      },
      update_attrs: -> { { dosage: "500mg", notes: "Split dose" } },
      invalid_attrs: -> { { name: nil } }
    }
  }.freeze

  def client_collection_path(resource_name)
    "/api/v1/client/#{resource_name}"
  end

  def client_member_path(resource_name, record)
    "#{client_collection_path(resource_name)}/#{record.id}"
  end

  def practitioner_collection_path(client, resource_name)
    "/api/v1/clients/#{client.id}/#{resource_name}"
  end

  def create_resource(resource_config, client, attrs = nil)
    client.public_send(resource_config[:association]).create!(attrs || resource_config[:valid_attrs].call)
  end

  def create_resource_via_api(resource_name, resource_config, client)
    session = ActionDispatch::Integration::Session.new(Rails.application)

    session.post client_collection_path(resource_name),
      params: resource_config[:valid_attrs].call,
      headers: auth_headers_for(client),
      as: :json

    raise "Failed to create #{resource_name} for test setup" unless session.response.status == 201

    resource_config[:model].find(session.response.parsed_body.dig("data", "id"))
  end

  shared_examples "client-owned health resource" do |resource_name, resource_config|
    let(:practitioner) { create_practitioner }
    let(:owned_client) { create_client(practitioner: practitioner) }
    let(:sibling_client) { create_client(practitioner: practitioner) }
    let(:other_practitioner) { create_practitioner }
    let(:foreign_client) { create_client(practitioner: other_practitioner) }

    it "requires client authentication for #{resource_name} index" do
      get client_collection_path(resource_name)

      expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
    end

    it "lists only the authenticated client's #{resource_name}" do
      record = create_resource_via_api(resource_name, resource_config, owned_client)
      create_resource_via_api(resource_name, resource_config, sibling_client)
      create_resource_via_api(resource_name, resource_config, foreign_client)

      get client_collection_path(resource_name), headers: auth_headers_for(owned_client)

      expect(response).to have_http_status(:ok)
      expect(response_data.map { |entry| entry["id"] }).to eq([ record.id ])
      expect(response_data.first).not_to have_key("client_id")
      expect(response_meta).to include(
        "page" => 1,
        "per_page" => 50,
        "total_count" => 1,
        "total_pages" => 1
      )
    end

    it "shows the authenticated client's #{resource_name.to_s.singularize}" do
      record = create_resource_via_api(resource_name, resource_config, owned_client)

      get client_member_path(resource_name, record), headers: auth_headers_for(owned_client)

      expect(response).to have_http_status(:ok)
      expect(response_data["id"]).to eq(record.id)
    end

    it "returns not found for another client's #{resource_name.to_s.singularize}" do
      sibling_record = create_resource_via_api(resource_name, resource_config, sibling_client)

      get client_member_path(resource_name, sibling_record), headers: auth_headers_for(owned_client)

      expect_error_response(status: :not_found, code: "not_found", message: "Not found")
    end

    it "creates a new #{resource_name.to_s.singularize}" do
      expect do
        post client_collection_path(resource_name),
          params: resource_config[:valid_attrs].call,
          headers: auth_headers_for(owned_client),
          as: :json
      end.to change { resource_config[:model].count }.by(1)

      expect(response).to have_http_status(:created)
      expect(response_data["id"]).to be_present
    end

    it "rejects invalid #{resource_name.to_s.singularize} creation" do
      post client_collection_path(resource_name),
        params: resource_config[:invalid_attrs].call,
        headers: auth_headers_for(owned_client),
        as: :json

      expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
      expect(json_response.dig("error", "details")).not_to be_empty
    end

    it "updates the authenticated client's #{resource_name.to_s.singularize}" do
      record = create_resource_via_api(resource_name, resource_config, owned_client)

      patch client_member_path(resource_name, record),
        params: resource_config[:update_attrs].call,
        headers: auth_headers_for(owned_client),
        as: :json

      expect(response).to have_http_status(:ok)
      resource_config[:update_attrs].call.each do |key, value|
        expect(record.reload.public_send(key)).to eq(value)
      end
    end

    it "rejects invalid #{resource_name.to_s.singularize} updates" do
      record = create_resource_via_api(resource_name, resource_config, owned_client)

      patch client_member_path(resource_name, record),
        params: resource_config[:invalid_attrs].call,
        headers: auth_headers_for(owned_client),
        as: :json

      expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
      expect(json_response.dig("error", "details")).not_to be_empty
    end

    it "deletes the authenticated client's #{resource_name.to_s.singularize}" do
      record = create_resource_via_api(resource_name, resource_config, owned_client)

      expect do
        delete client_member_path(resource_name, record), headers: auth_headers_for(owned_client)
      end.to change { resource_config[:model].count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "lets a practitioner list an associated client's #{resource_name}" do
      record = create_resource_via_api(resource_name, resource_config, owned_client)
      create_resource_via_api(resource_name, resource_config, sibling_client)

      get practitioner_collection_path(owned_client, resource_name), headers: auth_headers_for(practitioner)

      expect(response).to have_http_status(:ok)
      expect(response_data.map { |entry| entry["id"] }).to eq([ record.id ])
      expect(response_data.first["client_id"]).to eq(owned_client.id)
      expect(response_meta).to include(
        "page" => 1,
        "per_page" => 50,
        "total_count" => 1,
        "total_pages" => 1
      )
    end

    it "returns not found when a practitioner requests an unrelated client's #{resource_name}" do
      create_resource_via_api(resource_name, resource_config, foreign_client)

      get practitioner_collection_path(foreign_client, resource_name), headers: auth_headers_for(practitioner)

      expect_error_response(status: :not_found, code: "not_found", message: "Not found")
    end
  end

  RESOURCE_CONFIG.each do |resource_name, resource_config|
    include_examples "client-owned health resource", resource_name, resource_config
  end
end
