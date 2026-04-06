class CreateConsents < ActiveRecord::Migration[7.2]
  def change
    create_table :consents do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :consent_type, null: false
      t.string :version, null: false
      t.datetime :granted_at, null: false
      t.datetime :revoked_at
      t.string :ip_address

      t.timestamps
    end

    add_index :consents, [:patient_id, :consent_type]
  end
end
