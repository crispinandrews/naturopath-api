class CreateSymptoms < ActiveRecord::Migration[7.2]
  def change
    create_table :symptoms do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :severity
      t.datetime :occurred_at, null: false
      t.integer :duration_minutes
      t.text :notes

      t.timestamps
    end

    add_index :symptoms, [ :patient_id, :occurred_at ]
  end
end
