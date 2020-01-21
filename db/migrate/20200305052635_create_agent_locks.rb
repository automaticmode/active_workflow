class CreateAgentLocks < ActiveRecord::Migration[6.0]
  def change
    create_table :agent_locks do |t|
      t.integer 'agent_id'
      t.datetime 'locked_at'
      t.index ['agent_id'], name: 'index_agent_locks_on_agent_id', unique: true
    end
  end
end
