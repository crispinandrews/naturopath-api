class CreatePractitioners < ActiveRecord::Migration[7.2]
  def change
    create_table :practitioners do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :practice_name

      t.timestamps
    end

    add_index :practitioners, :email, unique: true
  end
end
