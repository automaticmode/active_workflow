module SortableMessages
  extend ActiveSupport::Concern

  included do
    validate :validate_messages_order
  end

  MESSAGES_ORDER_KEY = 'messages_order'
  MESSAGES_DESCRIPTION = 'messages created in each run'

  def description_messages_order(*args)
    self.class.description_messages_order(*args)
  end

  module ClassMethods
    def can_order_created_messages!
      raise 'Cannot order messages for agent that cannot create messages' if cannot_create_messages?
      prepend AutomaticSorter
    end

    def can_order_created_messages?
      include? AutomaticSorter
    end

    def cannot_order_created_messages?
      !can_order_created_messages?
    end

    def description_messages_order(messages = MESSAGES_DESCRIPTION, messages_order_key = MESSAGES_ORDER_KEY)
      <<-MD.lstrip
        To specify the order of #{messages}, set `#{messages_order_key}` to an array of sort keys, each of which looks like either `expression` or `[expression, type, descending]`, as described as follows:

        * _expression_ is a Liquid template to generate a string to be used as sort key.

        * _type_ (optional) is one of `string` (default), `number` and `time`, which specifies how to evaluate _expression_ for comparison.

        * _descending_ (optional) is a boolean value to determine if comparison should be done in descending (reverse) order, which defaults to `false`.

        Sort keys listed earlier take precedence over ones listed later.  For example, if you want to sort articles by the date and then by the author, specify `[["{{date}}", "time"], "{{author}}"]`.

        Sorting is done stably, so even if all messages have the same set of sort key values the original order is retained.  Also, a special Liquid variable `_index_` is provided, which contains the zero-based index number of each message, which means you can exactly reverse the order of messages by specifying `[["{{_index_}}", "number", true]]`.

        #{description_include_sort_info if messages == MESSAGES_DESCRIPTION}
      MD
    end

    def description_include_sort_info
      <<-MD.lstrip
        If the `include_sort_info` option is set, each created message will have a `sort_info` key whose value is a hash containing the following keys:

        * `position`: 1-based index of each message after the sort
        * `count`: Total number of messages sorted
      MD
    end
  end

  def can_order_created_messages?
    self.class.can_order_created_messages?
  end

  def cannot_order_created_messages?
    self.class.cannot_order_created_messages?
  end

  def messages_order(key = MESSAGES_ORDER_KEY)
    options[key]
  end

  def include_sort_info?
    boolify(interpolated['include_sort_info'])
  end

  def create_messages(messages)
    if include_sort_info?
      count = messages.count
      messages.each.with_index(1) do |message, position|
        message.payload[:sort_info] = {
          position: position,
          count: count
        }
        create_message(message)
      end
    else
      messages.each do |message|
        create_message(message)
      end
    end
  end

  module AutomaticSorter
    def check
      return super unless messages_order || include_sort_info?
      sorting_messages do
        super
      end
    end

    def receive(incoming_messages)
      return super unless messages_order || include_sort_info?
      # incoming messages should be processed sequentially
      incoming_messages.each do |message|
        sorting_messages do
          super([message])
        end
      end
    end

    def create_message(message)
      if @sortable_messages
        message = build_message(message)
        @sortable_messages << message
        message
      else
        super
      end
    end

    private

    def sorting_messages(&_block)
      @sortable_messages = []
      yield
    ensure
      messages, @sortable_messages = sort_messages(@sortable_messages), nil
      create_messages(messages)
    end
  end

  private

  EXPRESSION_PARSER = {
    'string' => ->(string) { string },
    'number' => ->(string) { string.to_f },
    'time'   => ->(string) { Time.zone.parse(string) }
  }.freeze
  EXPRESSION_TYPES = EXPRESSION_PARSER.keys.freeze

  # rubocop:disable Metrics/CyclomaticComplexity
  def validate_messages_order(messages_order_key = MESSAGES_ORDER_KEY)
    case order_by = messages_order(messages_order_key)
    when nil
    when Array
      # Each tuple may be either [expression, type, desc] or just
      # expression.
      order_by.each do |expression, type, desc|
        case expression
        when String
          # ok
        else
          errors.add(:base, "first element of each #{messages_order_key} tuple must be a Liquid template")
          break
        end
        case type
        when nil, *EXPRESSION_TYPES
          # ok
        else
          errors.add(:base, "second element of each #{messages_order_key} tuple must be #{EXPRESSION_TYPES.to_sentence(last_word_connector: ' or ')}")
          break
        end
        if !desc.nil? && boolify(desc).nil?
          errors.add(:base, "third element of each #{messages_order_key} tuple must be a boolean value")
          break
        end
      end
    else
      errors.add(:base, "#{messages_order_key} must be an array of arrays")
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # Sort given messages in order specified by the "messages_order" option
  def sort_messages(messages, messages_order_key = MESSAGES_ORDER_KEY)
    order_by = messages_order(messages_order_key).presence or
      return messages

    orders = order_by.map { |_, _, desc = false| boolify(desc) }

    Utils.sort_tuples!(
      messages.map.with_index do |message, index|
        interpolate_with(message) do
          interpolation_context['_index_'] = index
          order_by.map do |expression, type, _|
            string = interpolate_string(expression)
            begin
              EXPRESSION_PARSER[type || 'string'][string]
            rescue StandardError
              error "Cannot parse #{string.inspect} as #{type}; treating it as string"
              string
            end
          end
          # index is to make sorting stable
        end << index << message
      end,
      orders
    ).collect!(&:last)
  end
end
