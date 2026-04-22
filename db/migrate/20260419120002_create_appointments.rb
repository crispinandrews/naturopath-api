class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments do |t|
      t.references :client,       null: false, foreign_key: true
      t.references :practitioner, null: false, foreign_key: true
      t.datetime :scheduled_at,     null: false
      t.integer  :duration_minutes, null: false, default: 60
      t.string   :appointment_type, null: false
      t.string   :status,           null: false, default: "scheduled"
      t.text     :notes
      t.timestamps
    end

    add_index :appointments, [ :practitioner_id, :scheduled_at ]
    add_index :appointments, [ :client_id, :scheduled_at ]
  end
end
