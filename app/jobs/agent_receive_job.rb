class AgentReceiveJob < ActiveJob::Base
  # Given an Agent id and an array of Message ids, load the Agent, call #receive on it with the Message objects, and then
  # save it with an updated `last_receive_at` timestamp.
  # rubocop:disable Style/RescueStandardError
  def perform(agent_id, message_id)
    agent = Agent.find(agent_id)
    begin
      return if agent.unavailable?
      agent.receive(Message.find(message_id))
      agent.last_receive_at = Time.now
      agent.save!
    rescue => e
      agent.error "Exception during receive. #{e.message}: #{e.backtrace.join("\n")}"
      raise
    end
  end
  # rubocop:enable Style/RescueStandardError
end
