require 'rack'
require 'rack/handler/puma'

module RemoteAgentHelper
  # Simple rack server implementing remote agent API.
  class RemoteAgent
    # Start puma server with the agent. Returns launcher that can be
    # used to stop the server with `launcher.stop`.
    def self.start(host, port)
      app = self.new
      launcher = Rack::Handler::Puma.run(app, Host: host, Port: port, Silent: true)
    end

    def call(env)
      status  = 200
      headers = { 'Content-Type' => 'application/json' }

      request_body = Rack::Request.new(env).body.read
      request = JSON.parse(request_body)
      method = request['method']
      response = case method
                 when 'register'
                   register
                 when 'check'
                   check
                 when 'receive'
                   receive(request)
                 end

      [status, headers, [response.to_json]]
    end

    def register
      {
        result: {
          name: 'RemoteAgent',
          display_name: 'Remote Agent',
          description: 'Agent Description',
          default_options: { a: 'b' }
        }
      }
    end

    def check
      {
        result: {
          logs: [ 'Check performed' ],
          messages: [{ text: 'Remote message' }]
        }
      }
    end

    def receive(request)
      message = request['params']['message']
      {
        result: {
          logs: [ "Received message #{message['payload']['text']}" ]
        }
      }
    end
  end
end
