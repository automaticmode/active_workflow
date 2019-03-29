module Agents
  class WebhookAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!
    cannot_receive_messages!

    description do
      <<-MD
      The Webhook Agent will create messages by receiving webhooks from any source. In order to create messages with this agent, make a POST request to:

      ```
         https://#{ENV['DOMAIN']}/users/#{user.id}/web_requests/#{id || ':id'}/#{options['secret'] || ':secret'}
      ```

      #{'The placeholder symbols above will be replaced by their values once the agent is saved.' unless id}

      Options:

        * `secret` - A token that the host will provide for authentication.
        * `expected_receive_period_in_days` - How often you expect to receive
          messages this way. Used to determine if the agent is working.
        * `payload_path` - JSONPath of the attribute in the POST body to be
          used as the Message payload.  Set to `.` to return the entire message.
          If `payload_path` points to an array, Messages will be created for each element.
        * `verbs` - Comma-separated list of http verbs your agent will accept.
          For example, "post,get" will enable POST and GET requests. Defaults
          to "post".
        * `response` - The response message to the request. Defaults to 'Message Created'.
        * `response_headers` - An object with any custom response headers. (example: `{"Access-Control-Allow-Origin": "*"}`)
        * `code` - The response code to the request. Defaults to '201'. If the code is '301' or '302' the request will automatically be redirected to the url defined in "response".
        * `recaptcha_secret` - Setting this to a reCAPTCHA "secret" key makes your agent verify incoming requests with reCAPTCHA.  Don't forget to embed a reCAPTCHA snippet including your "site" key in the originating form(s).
        * `recaptcha_send_remote_addr` - Set this to true if your server is properly configured to set REMOTE_ADDR to the IP address of each visitor (instead of that of a proxy server).
      MD
    end

    message_description do
      <<-MD
        The message payload is based on the value of the `payload_path` option,
        which is set to `#{interpolated['payload_path']}`.
      MD
    end

    def default_options
      { 'secret' => 'supersecretstring',
        'expected_receive_period_in_days' => 1,
        'payload_path' => 'some_key' }
    end

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def receive_web_request(params, method, _format)
      # check the secret
      secret = params.delete('secret')
      return ['Not Authorized', 401] unless secret == interpolated['secret']

      # check the verbs
      verbs = (interpolated['verbs'] || 'post').split(/,/).map { |x| x.strip.downcase }.select(&:present?)
      return ["Please use #{verbs.join('/').upcase} requests only", 401] unless verbs.include?(method)

      # check the code
      code = (interpolated['code'].presence || 201).to_i

      # check the reCAPTCHA response if required
      if (recaptcha_secret = interpolated['recaptcha_secret'].presence)
        recaptcha_response = params.delete('g-recaptcha-response') or
          return ['Not Authorized', 401]

        parameters = {
          secret: recaptcha_secret,
          response: recaptcha_response
        }

        if boolify(interpolated['recaptcha_send_remote_addr'])
          parameters[:remoteip] = request.env['REMOTE_ADDR']
        end

        begin
          response = faraday.post('https://www.google.com/recaptcha/api/siteverify',
                                  parameters)
        rescue StandardError => e
          error "Verification failed: #{e.message}"
          return ['Not Authorized', 401]
        end

        JSON.parse(response.body)['success'] or
          return ['Not Authorized', 401]
      end

      # TODO: handle file uploads.
      [payload_for(params)].flatten.each do |payload|
        create_message(payload: payload)
      end

      if interpolated['response_headers'].presence
        [interpolated(params)['response'] || 'Message Created', code, 'text/plain', interpolated['response_headers'].presence]
      else
        [interpolated(params)['response'] || 'Message Created', code]
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    def working?
      message_created_within?(interpolated['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def validate_options
      unless options['secret'].present?
        errors.add(:base, "Must specify a secret for 'Authenticating' requests")
      end

      if options['code'].present? && options['code'].to_s !~ /\A\s*(\d+|\{.*)\s*\z/
        errors.add(:base, 'Must specify a code for request responses')
      end

      if options['code'].to_s.in?(%w[301 302]) &&
         !options['response'].present?
        errors.add(:base, 'Must specify a url for request redirect')
      end
    end

    def payload_for(params)
      Utils.value_at(params, interpolated['payload_path']) || {}
    end
  end
end
