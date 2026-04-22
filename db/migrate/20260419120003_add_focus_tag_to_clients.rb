class AddFocusTagToClients < ActiveRecord::Migration[7.2]
  def change
    add_column :clients, :focus_tag, :string
  end
end
