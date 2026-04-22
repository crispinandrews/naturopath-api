require "rails_helper"

RSpec.describe Appointment, type: :model do
  include RequestHelpers

  it "is invalid when the practitioner does not own the client" do
    practitioner = create_practitioner
    other_practitioner = create_practitioner
    client = create_client(practitioner: other_practitioner)

    appointment = Appointment.new(
      client: client,
      practitioner: practitioner,
      scheduled_at: 1.day.from_now,
      duration_minutes: 60,
      appointment_type: "follow_up",
      status: "scheduled"
    )

    expect(appointment).not_to be_valid
    expect(appointment.errors[:practitioner]).to include("must own the client")
  end
end
