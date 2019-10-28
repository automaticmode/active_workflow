module RemoteAgents
  def self.setup(env)
    urls = env.select { |k, v| k.start_with?('REMOTE_AGENT_URL') }.map(&:last)
    urls.each do |url|
      RemoteAgents::register_agent(url)
    end
  end

  def self.register_agent(url)
    response = Faraday.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { method: 'register', params: {} }.to_json
    end
    config = JSON.parse(response.body).fetch('result')
    class_name = "Agents::#{config['name']}"
    eval <<-DYNAMIC
      class ::#{class_name} < ::RemoteAgents::Agent
        remote_agent_config(#{config.inspect})

        remote_agent_url #{url.inspect}
      end
    DYNAMIC
    ::Agent::TYPES << class_name
  end

  class Agent < ::Agent
    class << self
      def remote_agent_config(config = nil)
        if config
          @remote_agent_config = config
          display_name(config['display_name'])
          description(config['description'])

          no_bulk_receive!
          default_schedule 'never'
        end
        @remote_agent_config
      end

      def remote_agent_url(url = nil)
        @remote_agent_url = url if url
        @remote_agent_url
      end
    end

    def default_options
      self.class.remote_agent_config['default_options']
    end

    def check
      response = remote_action(:check)
      handle_response(response)
    end

    def receive(messages)
      response = remote_action(:receive, messages.first)
      handle_response(response)
    end

    private

    def remote_agent_url
      self.class.remote_agent_url
    end

    def handle_response(response)
      result = response.fetch('result')
      handle_errors(result)
      handle_logs(result)
      handle_memory(result)
      handle_messages(result)
    end

    def handle_errors(result)
      result.fetch('errors', []).each do |data|
        error(data)
      end
    end

    def handle_logs(result)
      result.fetch('logs', []).each do |data|
        log(data)
      end
    end

    def handle_messages(result)
      result.fetch('messages', []).each do |payload|
        create_message(payload: payload)
      end
    end

    def handle_memory(result)
      self.memory = result['memory'] if result.key?('memory')
    end

    def perform_request(body)
      response = Faraday.post(remote_agent_url) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json
      end
      result = JSON.parse(response.body)
    end

    def remote_action(action, message = nil)
      body = {
        method: action,
        params: request_body.merge(message: message)
      }
      perform_request(body)
    end

    def request_body
      {
        options: self.options,
        memory: self.memory,
        credentials: credentials
      }
    end

    def credentials
      self.user.user_credentials.map do |credential|
        {
          name: credential.credential_name,
          value: credential.credential_value
        }
      end
    end
  end
end
