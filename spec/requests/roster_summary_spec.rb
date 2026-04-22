require "rails_helper"

RSpec.describe "Roster summary", type: :request do
  def get_roster(practitioner:, **params)
    get "/api/v1/clients/roster_summary",
      params: params,
      headers: auth_headers_for(practitioner)
  end

  it "requires practitioner authentication" do
    get "/api/v1/clients/roster_summary"
    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "returns an empty array when the practitioner has no clients" do
    practitioner = create_practitioner
    get_roster(practitioner: practitioner)
    expect(response).to have_http_status(:ok)
    expect(response_data).to eq([])
  end

  it "returns only the authenticated practitioner's own clients" do
    practitioner       = create_practitioner
    other_practitioner = create_practitioner
    own_client         = create_client(practitioner: practitioner)
    create_client(practitioner: other_practitioner)

    get_roster(practitioner: practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.map { |r| r["client_id"] }).to eq([own_client.id])
  end

  it "returns the correct per-client response shape" do
    practitioner = create_practitioner
    client       = create_client(practitioner: practitioner)

    get_roster(practitioner: practitioner)

    record = response_data.first
    expect(record["client_id"]).to eq(client.id)
    expect(record["energy_sparkline"]).to be_an(Array).and have_attributes(size: 30)
    expect(record["adherence_days"]).to be_an(Integer)
    expect(record["flags"]).to be_an(Array)
    expect(record.key?("last_logged_days_ago")).to be true
    expect(record.key?("next_appointment")).to be true
  end
end
