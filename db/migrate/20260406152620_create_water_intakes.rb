class CreateWaterIntakes < ActiveRecord::Migration[7.2]
  def change
    create_table :water_intakes do |t|
      t.references :patient, null: false, foreign_key: true
      t.integer :amount_ml, null: false
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :water_intakes, [ :patient_id, :recorded_at ]
  end
end
