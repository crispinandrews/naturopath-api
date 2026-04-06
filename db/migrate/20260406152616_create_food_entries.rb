class CreateFoodEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :food_entries do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :meal_type
      t.text :description
      t.datetime :consumed_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :food_entries, [ :patient_id, :consumed_at ]
  end
end
