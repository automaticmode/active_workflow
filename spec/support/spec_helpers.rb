module SpecHelpers
  def build_messages(options = {})
    options[:values].map.with_index do |tuple, index|
      message = Message.new
      message.agent = agents(:bob_status_agent)
      message.payload = (options[:pattern] || {}).dup.merge((options[:keys].zip(tuple)).inject({}) { |memo, (key, value)| memo[key] = value; memo })
      message.created_at = (100 - index).hours.ago
      message.updated_at = (100 - index).hours.ago
      message
    end
  end
end
