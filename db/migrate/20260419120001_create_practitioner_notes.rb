class CreatePractitionerNotes < ActiveRecord::Migration[7.2]
  def change
    create_table :practitioner_notes do |t|
      t.references :client, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :practitioners }
      t.string :note_type, null: false
      t.text :body, null: false
      t.boolean :pinned, null: false, default: false
      t.timestamps
    end

    add_index :practitioner_notes, [ :client_id, :created_at ]
    add_index :practitioner_notes, [ :client_id, :pinned ]
  end
end
