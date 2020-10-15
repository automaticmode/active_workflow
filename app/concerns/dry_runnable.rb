module DryRunnable
  extend ActiveSupport::Concern

  def dry_run!(message = nil)
    @dry_run = true

    log = StringIO.new
    @dry_run_started_at = Time.zone.now
    @dry_run_logger = Logger.new(log).tap { |logger|
      logger.formatter = proc { |severity, datetime, progname, message|
        elapsed_time = '%02d:%02d:%02d' % 2.times.inject([datetime - @dry_run_started_at]) { |(x, *xs)|
          [*x.divmod(60), *xs]
        }

        "[#{elapsed_time}] #{severity} -- #{progname}: #{message}\n"
      }
    }
    @dry_run_results = {
      messages: []
    }

    begin
      raise "#{short_type} does not support dry-run" unless can_dry_run?
      readonly!
      @dry_run_started_at = Time.zone.now
      @dry_run_logger.info('Dry Run started')
      if message
        raise 'This agent cannot receive a message!' unless can_receive_messages?
        receive(message)
      else
        check
      end
      @dry_run_logger.info('Dry Run finished')
    rescue => e
      @dry_run_logger.info('Dry Run failed')
      error "Exception during dry-run. #{e.message}: #{e.backtrace.join("\n")}"
    end

    @dry_run_results.update(
      memory: memory,
      log: log.string
    )
  ensure
    @dry_run = false
  end

  def dry_run?
    !!@dry_run
  end

  included do
    prepend Wrapper
  end

  module Wrapper
    attr_accessor :results

    def logger
      return super unless dry_run?
      @dry_run_logger
    end

    def save(options = {})
      return super unless dry_run?
      perform_validations(options)
    end

    def save!(options = {})
      return super unless dry_run?
      save(options) or raise_record_invalid
    end

    def log(message, options = {})
      return super unless dry_run?
      case options[:level] || 3
      when 0..2
        sev = Logger::DEBUG
      when 3
        sev = Logger::INFO
      else
        sev = Logger::ERROR
      end

      logger.log(sev, message)
    end

    def create_message(message)
      return super unless dry_run?
      if can_create_messages?
        message = build_message(message)
        @dry_run_results[:messages] << message.payload
        message
      else
        error 'This agent cannot create messages!'
      end
    end
  end
end
