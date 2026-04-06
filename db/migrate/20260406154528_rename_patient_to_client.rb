class RenamePatientToClient < ActiveRecord::Migration[7.2]
  def change
    rename_table :patients, :clients

    %i[food_entries symptoms energy_logs sleep_logs water_intakes supplements consents].each do |table|
      rename_column table, :patient_id, :client_id
    end
  end
end
