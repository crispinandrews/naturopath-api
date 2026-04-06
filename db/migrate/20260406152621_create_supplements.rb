class CreateSupplements < ActiveRecord::Migration[7.2]
  def change
    create_table :supplements do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :name, null: false
      t.string :dosage
      t.datetime :taken_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :supplements, [ :patient_id, :taken_at ]
  end
end
