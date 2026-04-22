require "rails_helper"

RSpec.describe "Appointments", type: :request do
  let(:practitioner) { create_practitioner }
  let(:client) { create_client(practitioner: practitioner) }

  def create_appointment(client:, practitioner:, **attrs)
    client.appointments.create!({
      practitioner: practitioner,
      scheduled_at: 1.week.from_now,
      duration_minutes: 60,
      appointment_type: "follow_up",
      status: "scheduled"
    }.merge(attrs))
  end

  # --- Schedule (cross-client) ---

  it "requires authentication for schedule index" do
    get "/api/v1/appointments"

    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "lists all appointments for the practitioner across clients" do
    client2 = create_client(practitioner: practitioner)
    create_appointment(client: client, practitioner: practitioner,
                       scheduled_at: 3.days.from_now)
    create_appointment(client: client2, practitioner: practitioner,
                       scheduled_at: 5.days.from_now)

    get "/api/v1/appointments", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.size).to eq(2)
    expect(response_meta).to include("total_count" => 2)
    expect(response_data.first["client"]).to include(
      "id" => client.id,
      "first_name" => client.first_name,
      "last_name" => client.last_name,
      "focus_tag" => nil
    )
  end

  it "does not include another practitioner's appointments in schedule" do
    other_practitioner = create_practitioner
    other_client = create_client(practitioner: other_practitioner)
    create_appointment(client: other_client, practitioner: other_practitioner)

    get "/api/v1/appointments", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data).to be_empty
  end

  it "filters schedule by status" do
    create_appointment(client: client, practitioner: practitioner, status: "scheduled")
    create_appointment(client: client, practitioner: practitioner, status: "completed")

    get "/api/v1/appointments",
      params: { status: "scheduled" },
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.size).to eq(1)
    expect(response_data.first["status"]).to eq("scheduled")
  end

  it "rejects an invalid schedule status filter" do
    get "/api/v1/appointments",
      params: { status: "pending" },
      headers: auth_headers_for(practitioner)

    expect_error_response(
      status: 422,
      code: "invalid_parameter",
      message: "Invalid status. Expected one of: scheduled, completed, cancelled, no_show"
    )
  end

  it "filters schedule by date range" do
    create_appointment(client: client, practitioner: practitioner,
                       scheduled_at: 2.days.from_now)
    create_appointment(client: client, practitioner: practitioner,
                       scheduled_at: 10.days.from_now)

    get "/api/v1/appointments",
      params: { from: 1.day.from_now.iso8601, to: 5.days.from_now.iso8601 },
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.size).to eq(1)
  end

  it "returns upcoming scheduled appointments ordered by soonest first" do
    create_appointment(client: client, practitioner: practitioner,
                       scheduled_at: 5.days.from_now)
    create_appointment(client: client, practitioner: practitioner,
                       scheduled_at: 2.days.from_now)
    create_appointment(client: client, practitioner: practitioner,
                       status: "completed", scheduled_at: 1.day.from_now)

    get "/api/v1/appointments/upcoming", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    data = json_response["data"]
    expect(data.size).to eq(2)
    expect(Time.parse(data.first["scheduled_at"])).to be < Time.parse(data.last["scheduled_at"])
    expect(data.first["client"]).to include(
      "id" => client.id,
      "first_name" => client.first_name,
      "last_name" => client.last_name,
      "focus_tag" => nil
    )
  end

  it "respects limit param on upcoming" do
    5.times do |i|
      create_appointment(client: client, practitioner: practitioner,
                         scheduled_at: (i + 1).days.from_now)
    end

    get "/api/v1/appointments/upcoming",
      params: { limit: 3 },
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(json_response["data"].size).to eq(3)
  end

  it "rejects upcoming limit above 50" do
    get "/api/v1/appointments/upcoming",
      params: { limit: 100 },
      headers: auth_headers_for(practitioner)

    expect_error_response(
      status: 422,
      code: "invalid_parameter",
      message: "limit must be less than or equal to 50"
    )
  end

  it "rejects a non-integer upcoming limit" do
    get "/api/v1/appointments/upcoming",
      params: { limit: "many" },
      headers: auth_headers_for(practitioner)

    expect_error_response(
      status: 422,
      code: "invalid_parameter",
      message: "limit must be an integer"
    )
  end

  # --- Client-nested CRUD ---

  it "requires auth for client-nested appointments" do
    get "/api/v1/clients/#{client.id}/appointments"

    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "returns 404 for another practitioner's client" do
    other_practitioner = create_practitioner
    foreign_client = create_client(practitioner: other_practitioner)

    get "/api/v1/clients/#{foreign_client.id}/appointments",
      headers: auth_headers_for(practitioner)

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end

  it "lists appointments for a client, newest scheduled first" do
    create_appointment(client: client, practitioner: practitioner,
                       scheduled_at: 3.days.from_now)
    create_appointment(client: client, practitioner: practitioner,
                       scheduled_at: 1.day.from_now)

    get "/api/v1/clients/#{client.id}/appointments",
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.size).to eq(2)
    expect(response_meta).to include("total_count" => 2)
    first_date = Time.parse(response_data.first["scheduled_at"])
    second_date = Time.parse(response_data.second["scheduled_at"])
    expect(first_date).to be > second_date
  end

  it "shows a single appointment" do
    appt = create_appointment(client: client, practitioner: practitioner,
                               appointment_type: "intake", notes: "Initial visit")

    get "/api/v1/clients/#{client.id}/appointments/#{appt.id}",
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data["id"]).to eq(appt.id)
    expect(response_data["appointment_type"]).to eq("intake")
    expect(response_data["notes"]).to eq("Initial visit")
    expect(response_data["client_id"]).to eq(client.id)
    expect(response_data["practitioner_id"]).to eq(practitioner.id)
  end

  it "creates an appointment" do
    expect do
      post "/api/v1/clients/#{client.id}/appointments",
        params: {
          scheduled_at: 7.days.from_now.iso8601,
          duration_minutes: 45,
          appointment_type: "check_in",
          status: "scheduled",
          notes: "Quick check"
        },
        headers: auth_headers_for(practitioner),
        as: :json
    end.to change(Appointment, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response_data["appointment_type"]).to eq("check_in")
    expect(response_data["duration_minutes"]).to eq(45)
    expect(response_data["practitioner_id"]).to eq(practitioner.id)
  end

  it "rejects invalid appointment_type" do
    post "/api/v1/clients/#{client.id}/appointments",
      params: {
        scheduled_at: 7.days.from_now.iso8601,
        duration_minutes: 60,
        appointment_type: "mystery",
        status: "scheduled"
      },
      headers: auth_headers_for(practitioner),
      as: :json

    expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
    expect(json_response.dig("error", "details")).to include(match(/appointment type/i))
  end

  it "rejects invalid status" do
    post "/api/v1/clients/#{client.id}/appointments",
      params: {
        scheduled_at: 7.days.from_now.iso8601,
        duration_minutes: 60,
        appointment_type: "follow_up",
        status: "pending"
      },
      headers: auth_headers_for(practitioner),
      as: :json

    expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
    expect(json_response.dig("error", "details")).to include(match(/status/i))
  end

  it "updates an appointment" do
    appt = create_appointment(client: client, practitioner: practitioner,
                               status: "scheduled")

    patch "/api/v1/clients/#{client.id}/appointments/#{appt.id}",
      params: { status: "completed", notes: "Went well" },
      headers: auth_headers_for(practitioner),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_data["status"]).to eq("completed")
    expect(response_data["notes"]).to eq("Went well")
    expect(appt.reload.status).to eq("completed")
  end

  it "destroys an appointment" do
    appt = create_appointment(client: client, practitioner: practitioner)

    expect do
      delete "/api/v1/clients/#{client.id}/appointments/#{appt.id}",
        headers: auth_headers_for(practitioner)
    end.to change(Appointment, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end

  it "returns 404 when accessing an appointment on a different client" do
    other_client = create_client(practitioner: practitioner)
    appt = create_appointment(client: other_client, practitioner: practitioner)

    get "/api/v1/clients/#{client.id}/appointments/#{appt.id}",
      headers: auth_headers_for(practitioner)

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end
end
