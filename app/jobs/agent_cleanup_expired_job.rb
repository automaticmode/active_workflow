class AgentCleanupExpiredJob < ActiveJob::Base
  queue_as :default

  def perform
    Message.cleanup_expired!
  end
end
