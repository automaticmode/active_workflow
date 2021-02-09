module Agents
  class TriggerAgent < Agent
    cannot_be_scheduled!
    can_dry_run!

    VALID_COMPARISON_TYPES = %w[regex !regex field<value field<=value
                                field==value field!=value field>=value
                                field>value not\ in].freeze

    description <<-MD
      Watches for a specific value in a message payload.

      The `rules` array contains hashes of `path`, `value`, and `type`.  The `path` value is a dotted path through a hash in [JSONPaths](http://goessner.net/articles/JsonPath/) syntax. For simple messages, this is usually just the name of the field you want, like 'text' for the text key of the message.

      The `type` can be one of #{VALID_COMPARISON_TYPES.map { |t| "`#{t}`" }.to_sentence} and compares with the `value`.  Note that regex patterns are matched case insensitively.  If you want case sensitive matching, prefix your pattern with `(?-i)`.

      The `value` can be a single value or an array of values. In the case of an array, all items must be strings, and if one or more values match, then the rule matches. Note: avoid using `field!=value` with arrays, you should use `not in` instead.

      By default, all rules must match for the agent to trigger. You can switch this so that only one rule must match by
      setting `must_match` to `1`.

      The resulting message will have a payload message of `message`.  You can use liquid templating in the `message.

      You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

      Set `keep_message` to `true` if you'd like to re-emit the incoming message, optionally merged with 'message' when provided.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between messages being received by this agent.
    MD

    message_description <<-MD
      Messages look like this:

          { "message": "Your message" }
    MD

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['rules'].present? &&
             options['rules'].all? { |rule| rule['type'].present? && VALID_COMPARISON_TYPES.include?(rule['type']) && rule['value'].present? && rule['path'].present? }
        errors.add(:base, 'expected_receive_period_in_days, message, and rules, with a type, value, and path for every rule, are required')
      end

      errors.add(:base, "message is required unless 'keep_message' is 'true'") unless options['message'].present? || keep_message?

      errors.add(:base, "keep_message, when present, must be 'true' or 'false'") unless options['keep_message'].blank? || %w[true false].include?(options['keep_message'])

      return unless options['must_match'].present?
      if options['must_match'].to_i < 1
        errors.add(:base, "If used, the 'must_match' option must be a positive integer")
      elsif options['must_match'].to_i > options['rules'].length
        errors.add(:base, "If used, the 'must_match' option must be equal to or less than the number of rules")
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    def default_options
      {
        'expected_receive_period_in_days' => '2',
        'keep_message' => 'false',
        'rules' => [{
          'type' => 'regex',
          'value' => 'foo\\d+bar',
          'path' => 'topkey.subkey.subkey.goal'
        }],
        'message' => "Looks like your pattern matched in '{{value}}'!"
      }
    end

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def receive(message)
      opts = interpolated(message)

      match_results = opts['rules'].map do |rule|
        value_at_path = Utils.value_at(message['payload'], rule['path'])
        rule_values = rule['value']
        rule_values = [rule_values] unless rule_values.is_a?(Array)

        if rule['type'] == 'not in'
          !rule_values.include?(value_at_path.to_s)
        elsif rule['type'] == 'field==value'
          rule_values.include?(value_at_path.to_s)
        else
          rule_values.any? do |rule_value|
            case rule['type']
            when 'regex'
              value_at_path.to_s =~ Regexp.new(rule_value, Regexp::IGNORECASE)
            when '!regex'
              value_at_path.to_s !~ Regexp.new(rule_value, Regexp::IGNORECASE)
            when 'field>value'
              value_at_path.to_f > rule_value.to_f
            when 'field>=value'
              value_at_path.to_f >= rule_value.to_f
            when 'field<value'
              value_at_path.to_f < rule_value.to_f
            when 'field<=value'
              value_at_path.to_f <= rule_value.to_f
            when 'field!=value'
              value_at_path.to_s != rule_value.to_s
            else
              raise "Invalid type of #{rule['type']} in TriggerAgent##{id}"
            end
          end
        end
      end

      return unless matches?(match_results)
      if keep_message?
        payload = message.payload.dup
        payload['message'] = opts['message'] if opts['message'].present?
      else
        payload = { 'message' => opts['message'] }
      end

      create_message payload: payload
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    def matches?(matches)
      if options['must_match'].present?
        matches.select { |match| match }.length >= options['must_match'].to_i
      else
        matches.all?
      end
    end

    def keep_message?
      boolify(interpolated['keep_message'])
    end
  end
end
