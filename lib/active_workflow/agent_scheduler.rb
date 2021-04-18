require 'rufus-scheduler'

module ActiveWorkflow
  class AgentScheduler
    attr_reader :scheduler, :mutex

    FAILED_JOBS_TO_KEEP = 100
    TAG = 'scheduler'.freeze
    SCHEDULE_TO_CRON = {
      '1m' => '*/1 * * * *',
      '2m' => '*/2 * * * *',
      '5m' => '*/5 * * * *',
      '10m' => '*/10 * * * *',
      '30m' => '*/30 * * * *',
      '1h' => '0 * * * *',
      '2h' => '0 */2 * * *',
      '5h' => '0 */5 * * *',
      '12h' => '0 */12 * * *',
      '1d' => '0 0 * * *',
      '2d' => '0 0 */2 * *',
      '7d' => '0 0 * * 1'
    }.freeze

    def initialize()
      @mutex = Mutex.new
      @scheduler = Rufus::Scheduler.new(frequency: ENV['SCHEDULER_FREQUENCY'].presence || 0.1)
    end

    def run
      tzinfo_friendly_timezone = ActiveSupport::TimeZone::MAPPING[ENV['TIMEZONE'].presence || 'Pacific Time (US & Canada)']

      puts "Starting scheduler" unless Rails.env.test?

      # Schedule message propagation.
      scheduler.every('1s', tag: TAG) do
        propagate!
      end

      # Schedule message cleanup.
      scheduler.every(ENV['MESSAGE_EXPIRATION_CHECK'].presence || '6h', tag: TAG) do
        cleanup_expired_messages!
      end

      # Schedule failed job cleanup.
      scheduler.every('1h', tag: TAG) do
        cleanup_failed_jobs!
      end

      # Schedule repeating messages.
      SCHEDULE_TO_CRON.keys.each do |schedule|
        scheduler.cron("#{SCHEDULE_TO_CRON[schedule]} #{tzinfo_friendly_timezone}", tag: TAG) do
          run_schedule "every_#{schedule}"
        end
      end

      # Schedule messages for specific times.
      24.times do |hour|
        scheduler.cron("0 #{hour} * * * " + tzinfo_friendly_timezone, tag: TAG) do
          run_schedule hour_to_schedule_name(hour)
        end
      end

      @scheduler.join
    end

    private

    def run_schedule(time)
      with_mutex do
        puts "Queuing schedule for #{time}"

        return if time == 'never'

        Agent.transaction do
          Agent.where('NOT disabled AND NOT deactivated AND schedule = ?', time).pluck('agents.id').each do |agent_id|
            AgentCheckJob.perform_later(agent_id)
          end
        end
      end
    end

    def propagate!
      with_mutex do
        return unless Delayed::Job.where(failed_at: nil, queue: 'propagation').count == 0

        puts 'Queuing message propagation'

        Agent.transaction do
          scope = Agent
                  .select('agents.id AS receiver_agent_id, sources.type AS source_agent_type, agents.type AS receiver_agent_type, messages.id AS message_id')
                  .joins('JOIN links ON (links.receiver_id = agents.id)')
                  .joins('JOIN agents AS sources ON (links.source_id = sources.id)')
                  .joins('JOIN messages ON (messages.agent_id = sources.id AND messages.id > links.message_id_at_creation)')
                  .where('NOT agents.disabled AND NOT agents.deactivated AND (agents.last_checked_message_id IS NULL OR messages.id > agents.last_checked_message_id)')

          sql = scope.to_sql

          agents_to_messages = {}
          Agent.connection.select_rows(sql).each do |receiver_agent_id, source_agent_type, receiver_agent_type, message_id|
            begin
              Object.const_get(source_agent_type)
              Object.const_get(receiver_agent_type)
            rescue NameError
              next
            end

            agents_to_messages[receiver_agent_id.to_i] ||= []
            agents_to_messages[receiver_agent_id.to_i] << message_id
          end

          Agent.where(id: agents_to_messages.keys).find_each do |agent|
            message_ids = agents_to_messages[agent.id].uniq
            # rubocop:disable Rails/SkipsModelValidations
            agent.update_attribute :last_checked_message_id, message_ids.max
            # rubocop:enable Rails/SkipsModelValidations

            message_ids.each do |message_id|
              AgentReceiveJob.perform_later(agent.id, message_id)
            end
          end
        end
      end
    end

    def cleanup_expired_messages!
      with_mutex do
        puts 'Running message cleanup'
        AgentCleanupExpiredJob.perform_later
      end
    end

    def cleanup_failed_jobs!
      num_to_keep = (ENV['FAILED_JOBS_TO_KEEP'].presence || FAILED_JOBS_TO_KEEP).to_i
      first_to_delete = Delayed::Job.where.not(failed_at: nil).order('failed_at DESC').offset(num_to_keep).limit(1).pluck(:failed_at).first
      Delayed::Job.where(['failed_at <= ?', first_to_delete]).delete_all if first_to_delete.present?
    end

    def hour_to_schedule_name(hour)
      if hour == 0
        'midnight'
      else
        "#{hour}h"
      end
    end

    def with_mutex
      mutex.synchronize do
        ActiveRecord::Base.connection_pool.with_connection do
          yield
        end
      end
    end
  end
end
