# Create practitioner
practitioner = Practitioner.find_or_create_by!(email: "practitioner@example.com") do |p|
  p.password = "password123"
  p.password_confirmation = "password123"
  p.first_name = "Maria"
  p.last_name = "Silva"
  p.practice_name = "Silva Naturopathy"
end

puts "Created practitioner: #{practitioner.email}"

# Create clients
client1 = Client.find_or_create_by!(email: "client1@example.com") do |c|
  c.practitioner = practitioner
  c.first_name = "João"
  c.last_name = "Santos"
  c.date_of_birth = Date.new(1990, 5, 15)
end

# Accept invite and set password for testing
unless client1.invite_accepted_at?
  client1.accept_invite!(password: "password123")
end

client2 = Client.find_or_create_by!(email: "client2@example.com") do |c|
  c.practitioner = practitioner
  c.first_name = "Ana"
  c.last_name = "Ferreira"
  c.date_of_birth = Date.new(1985, 8, 22)
end

unless client2.invite_accepted_at?
  client2.accept_invite!(password: "password123")
end

puts "Created clients: #{client1.email}, #{client2.email}"

# Create sample data for client1
base_date = 7.days.ago.beginning_of_day

7.times do |day|
  date = base_date + day.days

  # Food entries
  FoodEntry.find_or_create_by!(client: client1, consumed_at: date + 8.hours) do |e|
    e.meal_type = "breakfast"
    e.description = ["Oatmeal with berries", "Toast with avocado", "Smoothie bowl", "Eggs and vegetables", "Yogurt with granola", "Fruit salad", "Pancakes with honey"].sample
    e.notes = "Felt good after eating"
  end

  FoodEntry.find_or_create_by!(client: client1, consumed_at: date + 13.hours) do |e|
    e.meal_type = "lunch"
    e.description = ["Grilled chicken salad", "Vegetable soup", "Quinoa bowl", "Fish with rice", "Lentil stew", "Pasta with vegetables", "Wrap with hummus"].sample
  end

  FoodEntry.find_or_create_by!(client: client1, consumed_at: date + 19.hours) do |e|
    e.meal_type = "dinner"
    e.description = ["Salmon with sweet potato", "Stir-fry vegetables", "Bean curry", "Grilled vegetables with couscous", "Chicken soup", "Roasted vegetables", "Fish stew"].sample
  end

  # Energy log
  EnergyLog.find_or_create_by!(client: client1, recorded_at: date + 10.hours) do |e|
    e.level = rand(4..8)
    e.notes = "Morning energy check"
  end

  EnergyLog.find_or_create_by!(client: client1, recorded_at: date + 15.hours) do |e|
    e.level = rand(3..7)
    e.notes = "Afternoon energy check"
  end

  # Sleep log
  SleepLog.find_or_create_by!(client: client1, bedtime: date - 1.day + 23.hours) do |s|
    s.wake_time = date + 7.hours
    s.quality = rand(5..9)
    s.hours_slept = 8.0
  end

  # Water intake
  3.times do |i|
    WaterIntake.find_or_create_by!(client: client1, recorded_at: date + (8 + i * 4).hours) do |w|
      w.amount_ml = [250, 330, 500].sample
    end
  end

  # Supplements
  Supplement.find_or_create_by!(client: client1, taken_at: date + 8.hours, name: "Vitamin D") do |s|
    s.dosage = "2000 IU"
  end

  Supplement.find_or_create_by!(client: client1, taken_at: date + 8.hours, name: "Omega-3") do |s|
    s.dosage = "1000mg"
  end
end

# Some symptoms for client1
Symptom.find_or_create_by!(client: client1, name: "Headache", occurred_at: base_date + 2.days + 14.hours) do |s|
  s.severity = 6
  s.duration_minutes = 45
  s.notes = "After lunch, possibly related to screen time"
end

Symptom.find_or_create_by!(client: client1, name: "Bloating", occurred_at: base_date + 4.days + 20.hours) do |s|
  s.severity = 4
  s.duration_minutes = 120
  s.notes = "After dinner"
end

Symptom.find_or_create_by!(client: client1, name: "Fatigue", occurred_at: base_date + 5.days + 15.hours) do |s|
  s.severity = 5
  s.duration_minutes = 180
  s.notes = "Mid-afternoon slump"
end

# Consent record
Consent.find_or_create_by!(client: client1, consent_type: "health_data_processing") do |c|
  c.version = "1.0"
  c.granted_at = 30.days.ago
  c.ip_address = "127.0.0.1"
end

puts "Seeded sample data for #{client1.email}"
puts ""
puts "Test credentials:"
puts "  Practitioner: practitioner@example.com / password123"
puts "  Client 1:     client1@example.com / password123"
puts "  Client 2:     client2@example.com / password123"
