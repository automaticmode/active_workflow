module Agents
  class CommanderAgent < Agent
    include AgentControllerConcern

    cannot_create_messages!

    description <<-MD
      The Commander Agent is triggered by schedule or an incoming message, and commands other agents ("targets") to run, disable, configure, or enable themselves.

      # Action types

      Set `action` to one of the action types below:

      * `run`: Target Agents are run when this agent is triggered.

      * `disable`: Target Agents are disabled (if not) when this agent is triggered.

      * `enable`: Target Agents are enabled (if not) when this agent is triggered.

      * `configure`: Target Agents have their options updated with the contents of `configure_options`.

      You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

      - In templating, you can use the variable `target` to refer to each target agent, which has the following attributes: #{AgentDrop.instance_methods(false).map { |m| "`#{m}`" }.to_sentence}.

      # Targets

      Select Agents that you want to control from this CommanderAgent.
    MD

    def check
      control!
    end

    def receive(message)
      interpolate_with(message) do
        control!
      end
    end
  end
end
