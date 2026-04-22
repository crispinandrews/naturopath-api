require "rails_helper"

RSpec.describe "Practitioner notes", type: :request do
  let(:practitioner) { create_practitioner }
  let(:client) { create_client(practitioner: practitioner) }

  def create_note(client:, practitioner:, **attrs)
    client.practitioner_notes.create!({
      author: practitioner,
      note_type: "session",
      body: "Test note body",
      pinned: false
    }.merge(attrs))
  end

  it "requires practitioner authentication" do
    get "/api/v1/clients/#{client.id}/notes"

    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "returns 404 for another practitioner's client" do
    other_practitioner = create_practitioner
    foreign_client = create_client(practitioner: other_practitioner)
    create_note(client: foreign_client, practitioner: other_practitioner)

    get "/api/v1/clients/#{foreign_client.id}/notes",
      headers: auth_headers_for(practitioner)

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end

  it "lists notes for a client, newest first, paginated" do
    create_note(client: client, practitioner: practitioner, body: "First note",
                created_at: 2.days.ago)
    create_note(client: client, practitioner: practitioner, body: "Second note",
                created_at: 1.day.ago)

    get "/api/v1/clients/#{client.id}/notes",
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.size).to eq(2)
    expect(response_data.first["body"]).to eq("Second note")
    expect(response_meta).to include("total_count" => 2, "page" => 1)
  end

  it "paginates notes" do
    3.times { create_note(client: client, practitioner: practitioner) }

    get "/api/v1/clients/#{client.id}/notes",
      params: { per_page: 2, page: 2 },
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.size).to eq(1)
    expect(response_meta).to include("total_count" => 3, "page" => 2, "total_pages" => 2)
  end

  it "shows a single note" do
    note = create_note(client: client, practitioner: practitioner, body: "Show me")

    get "/api/v1/clients/#{client.id}/notes/#{note.id}",
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data["id"]).to eq(note.id)
    expect(response_data["body"]).to eq("Show me")
    expect(response_data["author_id"]).to eq(practitioner.id)
    expect(response_data["client_id"]).to eq(client.id)
  end

  it "returns 404 for a note on another practitioner's client" do
    other_practitioner = create_practitioner
    foreign_client = create_client(practitioner: other_practitioner)
    foreign_note = create_note(client: foreign_client, practitioner: other_practitioner)

    get "/api/v1/clients/#{foreign_client.id}/notes/#{foreign_note.id}",
      headers: auth_headers_for(practitioner)

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end

  it "creates a note" do
    expect do
      post "/api/v1/clients/#{client.id}/notes",
        params: { note_type: "session", body: "New session note", pinned: true },
        headers: auth_headers_for(practitioner),
        as: :json
    end.to change(PractitionerNote, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response_data["note_type"]).to eq("session")
    expect(response_data["body"]).to eq("New session note")
    expect(response_data["pinned"]).to be(true)
    expect(response_data["author_id"]).to eq(practitioner.id)
  end

  it "rejects note creation with invalid note_type" do
    post "/api/v1/clients/#{client.id}/notes",
      params: { note_type: "invalid_type", body: "Some body" },
      headers: auth_headers_for(practitioner),
      as: :json

    expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
    expect(json_response.dig("error", "details")).to include(match(/note type/i))
  end

  it "rejects note creation with blank body" do
    post "/api/v1/clients/#{client.id}/notes",
      params: { note_type: "session", body: "" },
      headers: auth_headers_for(practitioner),
      as: :json

    expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
  end

  it "updates a note" do
    note = create_note(client: client, practitioner: practitioner, body: "Before")

    patch "/api/v1/clients/#{client.id}/notes/#{note.id}",
      params: { body: "After", pinned: true },
      headers: auth_headers_for(practitioner),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_data["body"]).to eq("After")
    expect(response_data["pinned"]).to be(true)
    expect(note.reload.body).to eq("After")
  end

  it "destroys a note" do
    note = create_note(client: client, practitioner: practitioner)

    expect do
      delete "/api/v1/clients/#{client.id}/notes/#{note.id}",
        headers: auth_headers_for(practitioner)
    end.to change(PractitionerNote, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end

  it "returns 404 when updating a note on a different client" do
    other_client = create_client(practitioner: practitioner)
    note = create_note(client: other_client, practitioner: practitioner)

    patch "/api/v1/clients/#{client.id}/notes/#{note.id}",
      params: { body: "Hacked" },
      headers: auth_headers_for(practitioner),
      as: :json

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end
end
