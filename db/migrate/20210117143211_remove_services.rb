class RemoveServices < ActiveRecord::Migration[6.0]
  def change
    remove_column :agents, :service_id
    drop_table :services
  end
end
