# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_04_06_170000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "clients", force: :cascade do |t|
    t.bigint "practitioner_id", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.date "date_of_birth"
    t.string "invite_token"
    t.datetime "invite_accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "invite_expires_at"
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["invite_expires_at"], name: "index_clients_on_invite_expires_at"
    t.index ["invite_token"], name: "index_clients_on_invite_token", unique: true
    t.index ["practitioner_id"], name: "index_clients_on_practitioner_id"
  end

  create_table "consents", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "consent_type", null: false
    t.string "version", null: false
    t.datetime "granted_at", null: false
    t.datetime "revoked_at"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "consent_type"], name: "index_consents_on_client_id_and_consent_type"
    t.index ["client_id"], name: "index_consents_on_client_id"
  end

  create_table "energy_logs", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.integer "level", null: false
    t.datetime "recorded_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "recorded_at"], name: "index_energy_logs_on_client_id_and_recorded_at"
    t.index ["client_id"], name: "index_energy_logs_on_client_id"
  end

  create_table "food_entries", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "meal_type"
    t.text "description"
    t.datetime "consumed_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "consumed_at"], name: "index_food_entries_on_client_id_and_consumed_at"
    t.index ["client_id"], name: "index_food_entries_on_client_id"
  end

  create_table "practitioners", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "practice_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_practitioners_on_email", unique: true
  end

  create_table "sleep_logs", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "bedtime", null: false
    t.datetime "wake_time", null: false
    t.integer "quality"
    t.decimal "hours_slept"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "bedtime"], name: "index_sleep_logs_on_client_id_and_bedtime"
    t.index ["client_id"], name: "index_sleep_logs_on_client_id"
  end

  create_table "supplements", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "name", null: false
    t.string "dosage"
    t.datetime "taken_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "taken_at"], name: "index_supplements_on_client_id_and_taken_at"
    t.index ["client_id"], name: "index_supplements_on_client_id"
  end

  create_table "symptoms", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "name", null: false
    t.integer "severity"
    t.datetime "occurred_at", null: false
    t.integer "duration_minutes"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "occurred_at"], name: "index_symptoms_on_client_id_and_occurred_at"
    t.index ["client_id"], name: "index_symptoms_on_client_id"
  end

  create_table "water_intakes", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.integer "amount_ml", null: false
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "recorded_at"], name: "index_water_intakes_on_client_id_and_recorded_at"
    t.index ["client_id"], name: "index_water_intakes_on_client_id"
  end

  add_foreign_key "clients", "practitioners"
  add_foreign_key "consents", "clients"
  add_foreign_key "energy_logs", "clients"
  add_foreign_key "food_entries", "clients"
  add_foreign_key "sleep_logs", "clients"
  add_foreign_key "supplements", "clients"
  add_foreign_key "symptoms", "clients"
  add_foreign_key "water_intakes", "clients"
end
