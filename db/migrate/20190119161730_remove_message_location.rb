class RemoveMessageLocation < ActiveRecord::Migration[5.2]
  def change
    remove_column :messages, :lat
    remove_column :messages, :lng
  end
end
