class CreateEnergyLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :energy_logs do |t|
      t.references :patient, null: false, foreign_key: true
      t.integer :level, null: false
      t.datetime :recorded_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :energy_logs, [:patient_id, :recorded_at]
  end
end
