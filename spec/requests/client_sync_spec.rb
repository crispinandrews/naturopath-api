require "rails_helper"

RSpec.describe "Client sync", type: :request do
  let(:practitioner) { create_practitioner }
  let(:client) { create_client(practitioner: practitioner) }

  it "requires client authentication" do
    post "/api/v1/client/sync", params: { operations: [] }, as: :json

    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "syncs mixed valid and invalid operations with per-record results" do
    post "/api/v1/client/sync",
      params: {
        operations: [
          {
            op_id: "food-1",
            resource_type: "food_entries",
            action: "upsert",
            client_uuid: "food-local-1",
            attributes: {
              meal_type: "breakfast",
              description: "Oats and berries",
              consumed_at: "2026-04-05T09:00:00Z",
              notes: "Felt fine"
            }
          },
          {
            op_id: "water-1",
            resource_type: "water_intakes",
            action: "upsert",
            client_uuid: "water-local-1",
            attributes: {
              amount_ml: 0,
              recorded_at: "2026-04-05T10:00:00Z"
            }
          }
        ]
      },
      headers: auth_headers_for(client),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_meta).to include("total" => 2, "synced" => 1, "skipped" => 0, "failed" => 1)
    expect(response_data.first).to include(
      "op_id" => "food-1",
      "id" => client.food_entries.first.id,
      "resource_type" => "food_entries",
      "client_uuid" => "food-local-1",
      "status" => "synced"
    )
    expect(response_data.first.dig("record", "id")).to be_present
    expect(response_data.first.dig("record", "client_uuid")).to eq("food-local-1")
    expect(response_data.second).to include("status" => "failed")
    expect(response_data.second.dig("error", "code")).to eq("validation_failed")
    expect(client.food_entries.count).to eq(1)
    expect(client.water_intakes.count).to eq(0)
  end

  it "deduplicates retrying an upsert by client_uuid" do
    operation = {
      op_id: "energy-1",
      resource_type: "energy_logs",
      action: "upsert",
      client_uuid: "energy-local-1",
      attributes: {
        level: 4,
        recorded_at: "2026-04-05T11:00:00Z",
        notes: "Queued offline"
      }
    }

    2.times do
      post "/api/v1/client/sync",
        params: { operations: [ operation ] },
        headers: auth_headers_for(client),
        as: :json
    end

    expect(response).to have_http_status(:ok)
    expect(client.energy_logs.count).to eq(1)
    expect(client.energy_logs.first.client_uuid).to eq("energy-local-1")
  end

  it "applies later upserts to the existing client_uuid" do
    client.energy_logs.create!(
      client_uuid: "energy-local-2",
      level: 4,
      recorded_at: "2026-04-05T11:00:00Z",
      notes: "Original"
    )

    post "/api/v1/client/sync",
      params: {
        operations: [
          {
            op_id: "energy-2",
            resource_type: "energy_logs",
            action: "upsert",
            client_uuid: "energy-local-2",
            attributes: {
              level: 8,
              recorded_at: "2026-04-05T11:00:00Z",
              notes: "Updated offline"
            }
          }
        ]
      },
      headers: auth_headers_for(client),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_data.first).to include("status" => "synced")
    expect(client.energy_logs.count).to eq(1)
    expect(client.energy_logs.first.reload).to have_attributes(level: 8, notes: "Updated offline")
  end

  it "deletes records by client_uuid" do
    supplement = client.supplements.create!(
      client_uuid: "supplement-local-1",
      name: "Magnesium",
      dosage: "250mg",
      taken_at: "2026-04-05T08:00:00Z",
      notes: "With breakfast"
    )

    post "/api/v1/client/sync",
      params: {
        operations: [
          {
            op_id: "supplement-delete-1",
            resource_type: "supplements",
            action: "delete",
            client_uuid: supplement.client_uuid
          }
        ]
      },
      headers: auth_headers_for(client),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_data.first).to include("status" => "deleted")
    expect(response_data.first["id"]).to eq(supplement.id)
    expect(client.supplements.exists?(supplement.id)).to be(false)
  end

  it "skips deletes for records that are already absent" do
    post "/api/v1/client/sync",
      params: {
        operations: [
          {
            op_id: "supplement-delete-2",
            resource_type: "supplements",
            action: "delete",
            client_uuid: "missing-supplement-local-id"
          }
        ]
      },
      headers: auth_headers_for(client),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_meta).to include("total" => 1, "synced" => 0, "skipped" => 1, "failed" => 0)
    expect(response_data.first).to include(
      "op_id" => "supplement-delete-2",
      "id" => nil,
      "client_uuid" => "missing-supplement-local-id",
      "status" => "skipped",
      "record" => nil
    )
  end

  it "rejects malformed sync payloads" do
    post "/api/v1/client/sync",
      params: { operations: "not-an-array" },
      headers: auth_headers_for(client),
      as: :json

    expect_error_response(status: :unprocessable_entity, code: "invalid_sync_payload", message: "operations must be an array")
  end
end
