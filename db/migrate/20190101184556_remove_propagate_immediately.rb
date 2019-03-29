class RemovePropagateImmediately < ActiveRecord::Migration[5.2]
  def change
    remove_column :agents, :propagate_immediately
  end
end
