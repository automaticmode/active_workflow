module Agents
  class TwilioReceiveTextAgent < Agent
    cannot_be_scheduled!
    cannot_receive_messages!

    gem_dependency_check { defined?(Twilio) }

    description do
      <<-MD
      Receives text messages from Twilio and emits them as messages.

      #{'## Include `twilio-ruby` in your Gemfile to use this agent!' if dependencies_missing?}

      In order to create messages with this agent, configure Twilio to send POST requests to:

      ```
      #{post_url}
      ```

      #{'The placeholder symbols above will be replaced by their values once the agent is saved.' unless id}

      Options:

        * `server_url` must be set to the URL of your
        ActiveWorkflow installation (probably "https://#{ENV['DOMAIN']}"), which must be web-accessible.  Be sure to set http/https correctly.

        * `account_sid` and `auth_token` are your Twilio account credentials. `auth_token` must be the primary auth token for your Twilio accout.

        * If `reply_text` is set, it's contents will be sent back as a confirmation text.

        * `expected_receive_period_in_days` - How often you expect to receive messages this way. Used to determine if the agent is working.
      MD
    end

    def default_options
      {
        'account_sid' => 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'auth_token' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'server_url'    => "https://#{ENV['DOMAIN'].presence || 'example.com'}",
        'reply_text'    => '',
        'expected_receive_period_in_days' => 1
      }
    end

    def validate_options
      unless options['account_sid'].present? &&
             options['auth_token'].present? &&
             options['server_url'].present? &&
             options['expected_receive_period_in_days'].present?
        errors.add(:base, 'account_sid, auth_token, server_url, and expected_receive_period_in_days are all required')
      end
    end

    def post_url
      if interpolated['server_url'].present?
        "#{interpolated['server_url']}/users/#{user.id}/web_requests/#{id || ':id'}/sms-endpoint"
      else
        "https://#{ENV['DOMAIN']}/users/#{user.id}/web_requests/#{id || ':id'}/sms-endpoint"
      end
    end

    def receive_web_request(request)
      params = request.params.except(:action, :controller, :agent_id, :user_id, :format)
      headers = request.headers

      # check the last url param: 'secret'
      secret = params.delete('secret')
      return ['Not Authorized', 401] unless secret == 'sms-endpoint'

      signature = headers['HTTP_X_TWILIO_SIGNATURE']

      # validate from twilio
      @validator ||= Twilio::Util::RequestValidator.new interpolated['auth_token']
      unless @validator.validate(post_url, params, signature)
        error("Twilio Signature Failed to Validate\n\n" \
              "URL: #{post_url}\n\n" \
              "POST params: #{params.inspect}\n\n" \
              "Signature: #{signature}")
        return ['Not authorized', 401]
      end

      return ['Bad request', 400] unless create_message(payload: params)
      response = Twilio::TwiML::Response.new do |r|
        if interpolated['reply_text'].present?
          r.Message interpolated['reply_text']
        end
      end
      [response.text, 201, 'text/xml']
    end
  end
end
