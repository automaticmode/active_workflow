require 'custom_agent_context'

# This class is responsible for hooking up custom agents into the system.
# Currently it dynamically creates backing Agent class to do the heavy lifting and
# provides a 'context' to proxy data between the two.
class CustomAgents
  class Config
    attr_accessor :description, :display_name, :default_options
  end

  def self.register(klass)
    config = klass.register(Config.new)
    class_name = "Agents::Proxy#{klass}"
    display_name = config.display_name || klass
    eval <<-DYNAMIC
      class #{class_name} < ::Agent
        description #{config.description.inspect}

        default_schedule 'never'

        display_name #{display_name.inspect}

        no_bulk_receive!

        def default_options
          #{config.default_options.inspect}
        end

        def check
          impl.check
        end

        def receive(messages)
          messages.each do |message|
            impl.receive(message)
          end
        end

        private

        def impl
          @impl ||= begin
            context = CustomAgentContext.new(self)
            #{klass}.new(context)
          end
        end
      end
    DYNAMIC
    ::Agent::TYPES << class_name
  end
end

