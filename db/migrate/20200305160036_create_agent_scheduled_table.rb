class CreateAgentScheduledTable < ActiveRecord::Migration[6.0]
  def change
    create_table :agent_scheduled do |t|
      t.integer "agent_id"
      t.index ["agent_id"], name: "index_agent_scheduled_on_agent_id", unique: true
    end
  end
end
