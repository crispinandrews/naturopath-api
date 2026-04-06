class AddInviteExpiryToClients < ActiveRecord::Migration[7.2]
  def up
    add_column :clients, :invite_expires_at, :datetime
    add_index :clients, :invite_expires_at

    execute <<~SQL.squish
      UPDATE clients
      SET invite_expires_at = NOW() + INTERVAL '14 days'
      WHERE invite_token IS NOT NULL
        AND invite_accepted_at IS NULL
        AND invite_expires_at IS NULL
    SQL
  end

  def down
    remove_index :clients, :invite_expires_at
    remove_column :clients, :invite_expires_at
  end
end
