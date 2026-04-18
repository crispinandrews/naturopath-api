class AddClientUuidToHealthRecords < ActiveRecord::Migration[7.2]
  TABLES = %i[
    food_entries
    symptoms
    energy_logs
    sleep_logs
    water_intakes
    supplements
  ].freeze

  def change
    TABLES.each do |table_name|
      add_column table_name, :client_uuid, :string
      add_index table_name,
        %i[client_id client_uuid],
        unique: true,
        where: "client_uuid IS NOT NULL",
        name: "index_#{table_name}_on_client_id_and_client_uuid"
    end
  end
end
