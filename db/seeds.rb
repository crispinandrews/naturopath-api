# Create practitioner
practitioner = Practitioner.find_or_create_by!(email: "practitioner@example.com") do |p|
  p.password = "password123"
  p.password_confirmation = "password123"
  p.first_name = "Maria"
  p.last_name = "Silva"
  p.practice_name = "Silva Naturopathy"
end

puts "Created practitioner: #{practitioner.email}"

# ---------------------------------------------------------------------------
# Clients
# ---------------------------------------------------------------------------

clients_data = [
  { email: "client1@example.com", first_name: "João",   last_name: "Santos",   dob: Date.new(1990, 5, 15), focus_tag: "gut_health" },
  { email: "client2@example.com", first_name: "Ana",    last_name: "Ferreira", dob: Date.new(1985, 8, 22), focus_tag: "energy_fatigue" },
  { email: "client3@example.com", first_name: "Marco",  last_name: "Oliveira", dob: Date.new(1992, 3,  8),  focus_tag: "weight_management" },
  { email: "client4@example.com", first_name: "Lucia",  last_name: "Chen",     dob: Date.new(1988, 11, 30), focus_tag: "hormonal_balance" },
  { email: "client5@example.com", first_name: "Thomas", last_name: "Berg",     dob: Date.new(1978, 6, 17),  focus_tag: "stress_sleep" },
]

clients = clients_data.map do |data|
  client = Client.find_or_create_by!(email: data[:email]) do |c|
    c.practitioner  = practitioner
    c.first_name    = data[:first_name]
    c.last_name     = data[:last_name]
    c.date_of_birth = data[:dob]
    c.focus_tag     = data[:focus_tag]
  end

  # Ensure focus_tag is set on already-existing clients
  client.update_column(:focus_tag, data[:focus_tag]) if client.focus_tag != data[:focus_tag]

  unless client.invite_accepted_at?
    client.accept_invite!(password: "password123")
  end

  client
end

client1, client2, client3, client4, client5 = clients

puts "Clients: #{clients.map(&:email).join(', ')}"

# ---------------------------------------------------------------------------
# Sample tracking data for client1 (7 days)
# ---------------------------------------------------------------------------

base_date = 7.days.ago.beginning_of_day

7.times do |day|
  date = base_date + day.days

  FoodEntry.find_or_create_by!(client: client1, consumed_at: date + 8.hours) do |e|
    e.meal_type  = "breakfast"
    e.description = [ "Oatmeal with berries", "Toast with avocado", "Smoothie bowl", "Eggs and vegetables", "Yogurt with granola", "Fruit salad", "Pancakes with honey" ].sample
    e.notes = "Felt good after eating"
  end

  FoodEntry.find_or_create_by!(client: client1, consumed_at: date + 13.hours) do |e|
    e.meal_type  = "lunch"
    e.description = [ "Grilled chicken salad", "Vegetable soup", "Quinoa bowl", "Fish with rice", "Lentil stew", "Pasta with vegetables", "Wrap with hummus" ].sample
  end

  FoodEntry.find_or_create_by!(client: client1, consumed_at: date + 19.hours) do |e|
    e.meal_type  = "dinner"
    e.description = [ "Salmon with sweet potato", "Stir-fry vegetables", "Bean curry", "Grilled vegetables with couscous", "Chicken soup", "Roasted vegetables", "Fish stew" ].sample
  end

  EnergyLog.find_or_create_by!(client: client1, recorded_at: date + 10.hours) do |e|
    e.level = rand(4..8)
    e.notes = "Morning energy check"
  end

  EnergyLog.find_or_create_by!(client: client1, recorded_at: date + 15.hours) do |e|
    e.level = rand(3..7)
    e.notes = "Afternoon energy check"
  end

  SleepLog.find_or_create_by!(client: client1, bedtime: date - 1.day + 23.hours) do |s|
    s.wake_time   = date + 7.hours
    s.quality     = rand(5..9)
    s.hours_slept = 8.0
  end

  3.times do |i|
    WaterIntake.find_or_create_by!(client: client1, recorded_at: date + (8 + i * 4).hours) do |w|
      w.amount_ml = [ 250, 330, 500 ].sample
    end
  end

  Supplement.find_or_create_by!(client: client1, taken_at: date + 8.hours, name: "Vitamin D") do |s|
    s.dosage = "2000 IU"
  end

  Supplement.find_or_create_by!(client: client1, taken_at: date + 8.hours, name: "Omega-3") do |s|
    s.dosage = "1000mg"
  end
end

Symptom.find_or_create_by!(client: client1, name: "Headache", occurred_at: base_date + 2.days + 14.hours) do |s|
  s.severity         = 6
  s.duration_minutes = 45
  s.notes            = "After lunch, possibly related to screen time"
end

Symptom.find_or_create_by!(client: client1, name: "Bloating", occurred_at: base_date + 4.days + 20.hours) do |s|
  s.severity         = 4
  s.duration_minutes = 120
  s.notes            = "After dinner"
end

Symptom.find_or_create_by!(client: client1, name: "Fatigue", occurred_at: base_date + 5.days + 15.hours) do |s|
  s.severity         = 5
  s.duration_minutes = 180
  s.notes            = "Mid-afternoon slump"
end

Consent.find_or_create_by!(client: client1, consent_type: "health_data_processing") do |c|
  c.version    = "1.0"
  c.granted_at = 30.days.ago
  c.ip_address = "127.0.0.1"
end

puts "Seeded tracking data for #{client1.email}"

# ---------------------------------------------------------------------------
# Practitioner notes
# ---------------------------------------------------------------------------

notes_seed = [
  { client: client1, note_type: "intake",      pinned: true,  body: "Initial consultation. Client reports chronic bloating after meals, low energy in afternoons. History of IBS. Recommended elimination diet starting week 1." },
  { client: client1, note_type: "session",     pinned: false, body: "Week 3 follow-up. Bloating reduced significantly after removing gluten. Energy improving. Added probiotics to protocol." },
  { client: client1, note_type: "observation", pinned: false, body: "Food diary review — client eating late most evenings. Discussed circadian eating patterns." },

  { client: client2, note_type: "intake",      pinned: true,  body: "Client presents with persistent fatigue, brain fog, and disrupted sleep. Thyroid panel ordered. Discussed adrenal support options." },
  { client: client2, note_type: "session",     pinned: false, body: "Lab results in. TSH slightly elevated. Referred to GP for further assessment. Adjusted supplement stack — added ashwagandha and B-complex." },
  { client: client2, note_type: "message",     pinned: false, body: "Client messaged re: side effects from new supplement. Advised to halve dose and take with food. Monitor for one week." },

  { client: client3, note_type: "intake",      pinned: true,  body: "Weight management focus. BMI 28.4. Client exercises 2x/week but diet inconsistent. Set realistic 3-month goal of 4kg reduction via dietary changes." },
  { client: client3, note_type: "session",     pinned: false, body: "Month 1 check-in. Client down 1.5kg. Introduced intermittent fasting 16:8. Appetite control improving." },

  { client: client4, note_type: "intake",      pinned: true,  body: "Hormonal concerns — irregular cycle, mood swings, acne. Requested DUTCH hormone panel. Discussed seed cycling protocol." },
  { client: client4, note_type: "observation", pinned: false, body: "DUTCH results show elevated cortisol AM and low progesterone. Protocol adjusted to include vitex and magnesium glycinate." },

  { client: client5, note_type: "intake",      pinned: true,  body: "Presenting with high occupational stress, sleep onset difficulties, waking at 3am. Discussed sleep hygiene, blue light exposure, and evening routine." },
  { client: client5, note_type: "session",     pinned: false, body: "Two-week review. Sleep onset improved. Still waking early. Added L-theanine and phosphatidylserine to evening protocol." },
  { client: client5, note_type: "message",     pinned: false, body: "Client reports significant improvement in sleep depth. Wants to discuss stress management strategies further at next appointment." },
]

notes_seed.each do |attrs|
  PractitionerNote.find_or_create_by!(
    client:    attrs[:client],
    note_type: attrs[:note_type],
    body:      attrs[:body]
  ) do |n|
    n.author = practitioner
    n.pinned = attrs[:pinned]
  end
end

puts "Seeded practitioner notes"

# ---------------------------------------------------------------------------
# Appointments
# ---------------------------------------------------------------------------

appointments_seed = [
  # client1 — completed history + upcoming
  { client: client1, scheduled_at: 8.weeks.ago,  duration: 90, type: "intake",    status: "completed",  notes: "Initial consultation." },
  { client: client1, scheduled_at: 5.weeks.ago,  duration: 60, type: "follow_up", status: "completed",  notes: "Week 3 follow-up, diet progress review." },
  { client: client1, scheduled_at: 2.weeks.ago,  duration: 60, type: "labs_review", status: "completed", notes: "Reviewed food diary and supplement response." },
  { client: client1, scheduled_at: 1.week.from_now, duration: 60, type: "follow_up", status: "scheduled", notes: nil },

  # client2
  { client: client2, scheduled_at: 6.weeks.ago,  duration: 90, type: "intake",    status: "completed",  notes: "Initial intake." },
  { client: client2, scheduled_at: 3.weeks.ago,  duration: 60, type: "labs_review", status: "completed", notes: "Thyroid results review." },
  { client: client2, scheduled_at: 4.days.from_now, duration: 60, type: "check_in", status: "scheduled", notes: nil },

  # client3
  { client: client3, scheduled_at: 4.weeks.ago,  duration: 90, type: "intake",    status: "completed",  notes: "Initial consultation, weight management plan." },
  { client: client3, scheduled_at: 2.weeks.ago,  duration: 45, type: "check_in",  status: "completed",  notes: "Month 1 weigh-in and dietary review." },
  { client: client3, scheduled_at: 3.days.ago,   duration: 60, type: "follow_up", status: "no_show",    notes: "Client did not attend, rescheduled." },
  { client: client3, scheduled_at: 2.weeks.from_now, duration: 60, type: "follow_up", status: "scheduled", notes: nil },

  # client4
  { client: client4, scheduled_at: 5.weeks.ago,  duration: 90, type: "intake",    status: "completed",  notes: "Hormonal health intake." },
  { client: client4, scheduled_at: 10.days.ago,  duration: 60, type: "labs_review", status: "completed", notes: "DUTCH panel review." },
  { client: client4, scheduled_at: 3.weeks.from_now, duration: 60, type: "follow_up", status: "scheduled", notes: nil },

  # client5
  { client: client5, scheduled_at: 3.weeks.ago,  duration: 90, type: "intake",    status: "completed",  notes: "Stress and sleep intake." },
  { client: client5, scheduled_at: 1.week.ago,   duration: 45, type: "check_in",  status: "completed",  notes: "Two-week sleep review." },
  { client: client5, scheduled_at: 5.days.from_now, duration: 60, type: "follow_up", status: "scheduled", notes: nil },
]

appointments_seed.each do |attrs|
  Appointment.find_or_create_by!(
    client:       attrs[:client],
    scheduled_at: attrs[:scheduled_at],
  ) do |a|
    a.practitioner    = practitioner
    a.duration_minutes = attrs[:duration]
    a.appointment_type = attrs[:type]
    a.status           = attrs[:status]
    a.notes            = attrs[:notes]
  end
end

puts "Seeded appointments"
puts ""
puts "Test credentials:"
puts "  Practitioner: practitioner@example.com / password123"
puts "  Client 1 (gut health):         client1@example.com / password123"
puts "  Client 2 (energy/fatigue):     client2@example.com / password123"
puts "  Client 3 (weight management):  client3@example.com / password123"
puts "  Client 4 (hormonal balance):   client4@example.com / password123"
puts "  Client 5 (stress/sleep):       client5@example.com / password123"
