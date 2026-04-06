class CreateSleepLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :sleep_logs do |t|
      t.references :patient, null: false, foreign_key: true
      t.datetime :bedtime, null: false
      t.datetime :wake_time, null: false
      t.integer :quality
      t.decimal :hours_slept
      t.text :notes

      t.timestamps
    end

    add_index :sleep_logs, [:patient_id, :bedtime]
  end
end
