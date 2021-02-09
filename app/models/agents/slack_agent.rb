module Agents
  class SlackAgent < Agent
    DEFAULT_USERNAME = 'ActiveWorkflow'.freeze
    ALLOWED_PARAMS = %w[channel username unfurl_links attachments].freeze

    cannot_be_scheduled!
    cannot_create_messages!

    gem_dependency_check { defined?(Slack) }

    description <<-MD
      Lets you receive messages and send notifications to [Slack](https://slack.com/).

      #{'## Include `slack-notifier` in your Gemfile to use this agent!' if dependencies_missing?}

      To get started, you will first need to configure an incoming webhook.

      - Go to `https://my.slack.com/services/new/incoming-webhook`, choose a default channel and add the integration.

      Your webhook URL will look like: `https://hooks.slack.com/services/some/random/characters`

      Once the webhook has been configured, it can be used to post to other channels or direct to team members. To send a private message to team member, use their @username as the channel.

      You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

      Finally, you can set a custom icon for this webhook in `icon`, either as [emoji](http://www.emoji-cheat-sheet.com) or an URL to an image. Leaving this field blank will use the default icon for a webhook.
    MD

    def default_options
      {
        'webhook_url' => 'https://hooks.slack.com/services/...',
        'channel' => '#general',
        'username' => DEFAULT_USERNAME,
        'message' => "Hey there, It's ActiveWorkflow",
        'icon' => ''
      }
    end

    def validate_options
      unless options['webhook_url'].present? ||
             (options['auth_token'].present? && options['team_name'].present?) # compatibility
        errors.add(:base, 'webhook_url is required')
      end

      errors.add(:base, 'channel is required') unless options['channel'].present?
    end

    def webhook_url
      if (url = interpolated[:webhook_url].presence)
        url
      elsif (team = interpolated[:team_name].presence) && (token = interpolated[:auth_token])
        webhook = interpolated[:webhook].presence || 'incoming-webhook'
        # old style webhook URL
        "https://#{Rack::Utils.escape_path(team)}.slack.com/services/hooks/#{Rack::Utils.escape_path(webhook)}?token=#{Rack::Utils.escape(token)}"
      end
    end

    def username
      interpolated[:username].presence || DEFAULT_USERNAME
    end

    def slack_notifier
      @slack_notifier ||= Slack::Notifier.new(webhook_url, username: username)
    end

    def filter_options(opts)
      opts.select { |key, _value| ALLOWED_PARAMS.include? key }.symbolize_keys
    end

    def receive(message)
      opts = interpolated(message)
      slack_opts = filter_options(opts)
      if opts[:icon].present?
        if /^:/.match?(opts[:icon])
          slack_opts[:icon_emoji] = opts[:icon]
        else
          slack_opts[:icon_url] = opts[:icon]
        end
      end
      slack_notifier.ping opts[:message], slack_opts
    end
  end
end
