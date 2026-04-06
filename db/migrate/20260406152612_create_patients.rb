class CreatePatients < ActiveRecord::Migration[7.2]
  def change
    create_table :patients do |t|
      t.references :practitioner, null: false, foreign_key: true
      t.string :email, null: false
      t.string :password_digest
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.date :date_of_birth
      t.string :invite_token
      t.datetime :invite_accepted_at

      t.timestamps
    end

    add_index :patients, :email, unique: true
    add_index :patients, :invite_token, unique: true
  end
end
