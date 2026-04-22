require "rails_helper"

RSpec.describe PractitionerNote, type: :model do
  include RequestHelpers

  it "is invalid when the author does not own the client" do
    practitioner = create_practitioner
    other_practitioner = create_practitioner
    client = create_client(practitioner: other_practitioner)

    note = PractitionerNote.new(
      client: client,
      author: practitioner,
      note_type: "session",
      body: "Cross-tenant note"
    )

    expect(note).not_to be_valid
    expect(note.errors[:author]).to include("must own the client")
  end
end
