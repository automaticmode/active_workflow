require 'rails_helper'

describe Message do
  describe '#reemit' do
    it 'creates a new message identical to itself' do
      messages(:bob_website_agent_message).created_at = 2.weeks.ago
      expect {
        messages(:bob_website_agent_message).reemit!
      }.to change { Message.count }.by(1)
      expect(Message.last.payload).to eq(messages(:bob_website_agent_message).payload)
      expect(Message.last.agent).to eq(messages(:bob_website_agent_message).agent)
      expect(Message.last.created_at.to_i).to be_within(2).of(Time.now.to_i)
    end
  end

  describe '.cleanup_expired!' do
    it 'removes any Messages whose expired_at date is non-null and in the past, updating Agent counter caches' do
      half_hour_message = agents(:jane_status_agent).create_message expires_at: 20.minutes.from_now
      one_hour_message = agents(:bob_status_agent).create_message expires_at: 1.hours.from_now
      two_hour_message = agents(:jane_status_agent).create_message expires_at: 2.hours.from_now
      three_hour_message = agents(:jane_status_agent).create_message expires_at: 3.hours.from_now
      non_expiring_message = agents(:bob_status_agent).create_message({})

      initial_bob_count = agents(:bob_status_agent).reload.messages_count
      initial_jane_count = agents(:jane_status_agent).reload.messages_count

      current_time = Time.now
      stub(Time).now { current_time }

      Message.cleanup_expired!
      expect(Message.find_by_id(half_hour_message.id)).not_to be_nil
      expect(Message.find_by_id(one_hour_message.id)).not_to be_nil
      expect(Message.find_by_id(two_hour_message.id)).not_to be_nil
      expect(Message.find_by_id(three_hour_message.id)).not_to be_nil
      expect(Message.find_by_id(non_expiring_message.id)).not_to be_nil
      expect(agents(:bob_status_agent).reload.messages_count).to eq(initial_bob_count)
      expect(agents(:jane_status_agent).reload.messages_count).to eq(initial_jane_count)

      current_time = 119.minutes.from_now # move almost 2 hours into the future
      Message.cleanup_expired!
      expect(Message.find_by_id(half_hour_message.id)).to be_nil
      expect(Message.find_by_id(one_hour_message.id)).to be_nil
      expect(Message.find_by_id(two_hour_message.id)).not_to be_nil
      expect(Message.find_by_id(three_hour_message.id)).not_to be_nil
      expect(Message.find_by_id(non_expiring_message.id)).not_to be_nil
      expect(agents(:bob_status_agent).reload.messages_count).to eq(initial_bob_count - 1)
      expect(agents(:jane_status_agent).reload.messages_count).to eq(initial_jane_count - 1)

      current_time = 2.minutes.from_now # move 2 minutes further into the future
      Message.cleanup_expired!
      expect(Message.find_by_id(two_hour_message.id)).to be_nil
      expect(Message.find_by_id(three_hour_message.id)).not_to be_nil
      expect(Message.find_by_id(non_expiring_message.id)).not_to be_nil
      expect(agents(:bob_status_agent).reload.messages_count).to eq(initial_bob_count - 1)
      expect(agents(:jane_status_agent).reload.messages_count).to eq(initial_jane_count - 2)
    end

    it "doesn't touch Messages with no expired_at" do
      message = Message.new
      message.agent = agents(:jane_status_agent)
      message.expires_at = nil
      message.save!

      current_time = Time.now
      stub(Time).now { current_time }

      Message.cleanup_expired!
      expect(Message.find_by_id(message.id)).not_to be_nil
      current_time = 2.days.from_now
      Message.cleanup_expired!
      expect(Message.find_by_id(message.id)).not_to be_nil
    end

    it 'never keeps the latest Message' do
      Message.delete_all
      message1 = agents(:jane_status_agent).create_message expires_at: 1.minute.ago
      message2 = agents(:bob_status_agent).create_message expires_at: 1.minute.ago

      Message.cleanup_expired!
      expect(Message.all.pluck(:id)).to be_empty
    end
  end

  describe 'after destroy' do
    it 'nullifies any dependent AgentLogs' do
      expect(agent_logs(:log_for_jane_website_agent).outbound_message_id).to be_present
      expect(agent_logs(:log_for_bob_website_agent).outbound_message_id).to be_present

      agent_logs(:log_for_bob_website_agent).outbound_message.destroy

      expect(agent_logs(:log_for_jane_website_agent).reload.outbound_message_id).to be_present
      expect(agent_logs(:log_for_bob_website_agent).reload.outbound_message_id).to be_nil
    end
  end

  describe 'caches' do
    describe 'when an message is created' do
      it 'updates a counter cache on agent' do
        expect {
          agents(:jane_status_agent).messages.create!(user: users(:jane))
        }.to change { agents(:jane_status_agent).reload.messages_count }.by(1)
      end

      it 'updates last_message_at on agent' do
        expect {
          agents(:jane_status_agent).messages.create!(user: users(:jane))
        }.to change { agents(:jane_status_agent).reload.last_message_at }
      end
    end

    describe 'when an message is updated' do
      it 'does not touch the last_message_at on the agent' do
        message = agents(:jane_status_agent).messages.create!(user: users(:jane))

        agents(:jane_status_agent).update_attribute :last_message_at, 2.days.ago

        expect {
          message.update_attribute :payload, { 'hello' => 'world' }
        }.not_to change { agents(:jane_status_agent).reload.last_message_at }
      end
    end
  end
end

describe MessageDrop do
  def interpolate(string, message)
    message.agent.interpolate_string(string, message.to_liquid)
  end

  before do
    @message = Message.new
    @message.agent = agents(:jane_status_agent)
    @message.created_at = Time.now
    @message.payload = {
      'title' => 'some title',
      'url' => 'http://some.site.example.org/'
    }
    @message.save!
  end

  it 'should be created via Agent#to_liquid' do
    expect(@message.to_liquid.class).to be(MessageDrop)
  end

  it 'should have attributes of its payload' do
    t = '{{title}}: {{url}}'
    expect(interpolate(t, @message)).to eq('some title: http://some.site.example.org/')
  end

  it 'should use created_at from the payload if it exists' do
    created_at = @message.created_at - 86_400
    # Avoid timezone issue by using %s
    @message.payload['created_at'] = created_at.strftime('%s')
    @message.save!
    t = '{{created_at | date:"%s" }}'
    expect(interpolate(t, @message)).to eq(created_at.strftime('%s'))
  end

  it 'should be iteratable' do
    # to_liquid returns self
    t = "{% for pair in to_liquid %}{{pair | join:':' }}\n{% endfor %}"
    expect(interpolate(t, @message)).to eq("title:some title\nurl:http://some.site.example.org/\n")
  end

  it 'should have created_at' do
    t = '{{created_at | date:"%FT%T%z" }}'
    expect(interpolate(t, @message)).to eq(@message.created_at.strftime('%FT%T%z'))
  end
end
