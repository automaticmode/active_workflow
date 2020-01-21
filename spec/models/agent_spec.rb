require 'rails_helper'

describe Agent do
  it_behaves_like WorkingHelpers

  describe '.active/inactive' do
    let(:agent) { agents(:jane_website_agent) }

    it 'is active per default' do
      expect(Agent.active).to include(agent)
      expect(Agent.inactive).not_to include(agent)
    end

    it 'is not active when disabled' do
      agent.update_attribute(:disabled, true)
      expect(Agent.active).not_to include(agent)
      expect(Agent.inactive).to include(agent)
    end

    it 'is not active when deactivated' do
      agent.update_attribute(:deactivated, true)
      expect(Agent.active).not_to include(agent)
      expect(Agent.inactive).to include(agent)
    end

    it 'is not active when disabled and deactivated' do
      agent.update_attribute(:disabled, true)
      agent.update_attribute(:deactivated, true)
      expect(Agent.active).not_to include(agent)
      expect(Agent.inactive).to include(agent)
    end
  end

  describe 'credential' do
    it 'should return the value of the credential when credential is present' do
      expect(agents(:bob_status_agent).credential('aws_secret')).to eq(user_credentials(:bob_aws_secret).credential_value)
    end

    it 'should return nil when credential is not present' do
      expect(agents(:bob_status_agent).credential('non_existing_credential')).to eq(nil)
    end

    it 'should memoize the load' do
      mock.any_instance_of(UserCredential).credential_value.twice { 'foo' }
      expect(agents(:bob_status_agent).credential('aws_secret')).to eq('foo')
      expect(agents(:bob_status_agent).credential('aws_secret')).to eq('foo')
      agents(:bob_status_agent).reload
      expect(agents(:bob_status_agent).credential('aws_secret')).to eq('foo')
      expect(agents(:bob_status_agent).credential('aws_secret')).to eq('foo')
    end
  end

  describe 'changes to type' do
    it 'validates types' do
      source = Agent.new
      source.type = 'Agents::HttpStatusAgent'
      expect(source).to have(0).errors_on(:type)
      source.type = 'Agents::WebsiteAgent'
      expect(source).to have(0).errors_on(:type)
      source.type = 'Agents::Fake'
      expect(source).to have(1).error_on(:type)
    end

    it 'disallows changes to type once a record has been saved' do
      source = agents(:bob_website_agent)
      source.type = 'Agents::HttpStatusAgent'
      expect(source).to have(1).error_on(:type)
    end

    it 'should know about available types' do
      expect(Agent.types).to include(Agents::HttpStatusAgent, Agents::WebsiteAgent)
    end
  end

  describe 'with an example Agent' do
    class Agents::SomethingSource < Agent
      default_schedule '14h'

      display_name 'Something Agent'

      def check
        create_message payload: {}
      end

      def validate_options
        errors.add(:base, 'bad is bad') if options[:bad]
      end
    end

    class Agents::CannotBeScheduled < Agent
      cannot_be_scheduled!

      def receive(message)
        create_message payload: { messages_received: 1 }
      end
    end

    before do
      stub(Agents::SomethingSource).valid_type?('Agents::SomethingSource') { true }
      stub(Agents::CannotBeScheduled).valid_type?('Agents::CannotBeScheduled') { true }
    end

    describe Agents::SomethingSource do
      let(:new_instance) do
        agent = Agents::SomethingSource.new(name: 'some agent')
        agent.user = users(:bob)
        agent
      end

      it_behaves_like LiquidInterpolatable
      it_behaves_like HasGuid
    end

    describe '.short_type' do
      it "returns a short name without 'Agents::'" do
        expect(Agents::SomethingSource.new.short_type).to eq('SomethingSource')
        expect(Agents::CannotBeScheduled.new.short_type).to eq('CannotBeScheduled')
      end
    end

    describe '.default_schedule' do
      it 'stores the default on the class' do
        expect(Agents::SomethingSource.default_schedule).to eq('14h')
        expect(Agents::SomethingSource.new.default_schedule).to eq('14h')
      end

      it 'sets the default on new instances, allows setting new schedules, and prevents invalid schedules' do
        @checker = Agents::SomethingSource.new(name: 'something')
        @checker.user = users(:bob)
        expect(@checker.schedule).to eq('14h')
        @checker.save!
        expect(@checker.reload.schedule).to eq('14h')
        @checker.update_attribute :schedule, '17h'
        expect(@checker.reload.schedule).to eq('17h')

        expect(@checker.reload.schedule).to eq('17h')

        @checker.schedule = 'this_is_not_real'
        expect(@checker).to have(1).errors_on(:schedule)
      end

      it 'should have an empty schedule if it cannot_be_scheduled' do
        @checker = Agents::CannotBeScheduled.new(name: 'something')
        @checker.user = users(:bob)
        expect(@checker.schedule).to be_nil
        expect(@checker).to be_valid
        @checker.schedule = '17h'
        @checker.save!
        expect(@checker.schedule).to be_nil

        @checker.schedule = '17h'
        expect(@checker).to have(0).errors_on(:schedule)
        expect(@checker.schedule).to be_nil
      end
    end

    describe '.display_name' do
      it 'stores the default on the class' do
        expect(Agents::SomethingSource.display_name).to eq('Something Agent')
        expect(Agents::SomethingSource.new.display_name)
          .to eq('Something Agent')
      end
    end

    describe '#create_message' do
      before do
        @checker = Agents::SomethingSource.new(name: 'something')
        @checker.user = users(:bob)
        @checker.save!
      end

      it "should use the checker's user" do
        @checker.check
        expect(Message.last.user).to eq(@checker.user)
      end

      it "should log an error if the Agent has been marked with 'cannot_create_messages!'" do
        mock(@checker).can_create_messages? { false }
        expect {
          @checker.check
        }.not_to change { Message.count }
        expect(@checker.logs.first.message).to match(/cannot create messages/i)
      end
    end

    describe '.async_check' do
      before do
        @checker = Agents::SomethingSource.new(name: 'something')
        @checker.user = users(:bob)
        @checker.save!
      end

      it 'records last_check_at and calls check on the given Agent' do
        mock(@checker).check.once {
          @checker.options[:new] = true
        }

        mock(Agent).find(@checker.id) { @checker }

        expect(@checker.last_check_at).to be_nil
        Agents::SomethingSource.async_check(@checker.id)
        expect(@checker.reload.last_check_at).to be_within(2).of(Time.now)
        expect(@checker.reload.options[:new]).to be_truthy # Show that we save options
      end

      it 'should log exceptions' do
        mock(@checker).check.once {
          raise 'foo'
        }
        mock(Agent).find(@checker.id) { @checker }
        expect {
          Agents::SomethingSource.async_check(@checker.id)
        }.to raise_error(RuntimeError)
        log = @checker.logs.first
        expect(log.message).to match(/Exception/)
        expect(log.level).to eq(4)
      end

      it 'should not run disabled Agents' do
        mock(Agent).find(agents(:bob_status_agent).id) { agents(:bob_status_agent) }
        do_not_allow(agents(:bob_status_agent)).check
        agents(:bob_status_agent).update_attribute :disabled, true
        Agent.async_check(agents(:bob_status_agent).id)
      end
    end

    describe '.async_receive' do
      it 'should not run disabled Agents' do
        mock(Agent).find(agents(:bob_notifier_agent).id) { agents(:bob_notifier_agent) }
        do_not_allow(agents(:bob_notifier_agent)).receive
        agents(:bob_notifier_agent).update_attribute :disabled, true

        Agent.async_receive(agents(:bob_notifier_agent).id, 1)
      end
    end

    describe 'validations' do
      it 'calls validate_options' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)
        agent.options[:bad] = true
        expect(agent).to have(1).error_on(:base)
        agent.options[:bad] = false
        expect(agent).to have(0).errors_on(:base)
      end

      it 'makes options symbol-indifferent before validating' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)
        agent.options['bad'] = true
        expect(agent).to have(1).error_on(:base)
        agent.options['bad'] = false
        expect(agent).to have(0).errors_on(:base)
      end

      it 'makes memory symbol-indifferent before validating' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)
        agent.memory['bad'] = 2
        agent.save
        expect(agent.memory[:bad]).to eq(2)
      end

      it 'should work when assigned a hash or JSON string' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.memory = {}
        expect(agent.memory).to eq({})
        expect(agent.memory['foo']).to be_nil

        agent.memory = ''
        expect(agent.memory['foo']).to be_nil
        expect(agent.memory).to eq({})

        agent.memory = '{"hi": "there"}'
        expect(agent.memory).to eq({ 'hi' => 'there' })

        agent.memory = '{invalid}'
        expect(agent.memory).to eq({ 'hi' => 'there' })
        expect(agent).to have(1).errors_on(:memory)

        agent.memory = '{}'
        expect(agent.memory['foo']).to be_nil
        expect(agent.memory).to eq({})
        expect(agent).to have(0).errors_on(:memory)

        agent.options = '{}'
        expect(agent.options['foo']).to be_nil
        expect(agent.options).to eq({})
        expect(agent).to have(0).errors_on(:options)

        agent.options = '{"hi": 2}'
        expect(agent.options['hi']).to eq(2)
        expect(agent).to have(0).errors_on(:options)

        agent.options = '{"hi": wut}'
        expect(agent.options['hi']).to eq(2)
        expect(agent).to have(1).errors_on(:options)
        expect(agent.errors_on(:options)).to include('was assigned invalid JSON')

        agent.options = 5
        expect(agent.options['hi']).to eq(2)
        expect(agent).to have(1).errors_on(:options)
        expect(agent.errors_on(:options)).to include("cannot be set to an instance of #{2.class}") # Integer (ruby >=2.4) or Fixnum (ruby <2.4)
      end

      it 'should not allow source agents owned by other people' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)
        agent.source_ids = [agents(:bob_status_agent).id]
        expect(agent).to have(0).errors_on(:sources)
        agent.source_ids = [agents(:jane_status_agent).id]
        expect(agent).to have(1).errors_on(:sources)
        agent.user = users(:jane)
        expect(agent).to have(0).errors_on(:sources)
      end

      it 'should not allow target agents owned by other people' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)
        agent.receiver_ids = [agents(:bob_status_agent).id]
        expect(agent).to have(0).errors_on(:receivers)
        agent.receiver_ids = [agents(:jane_status_agent).id]
        expect(agent).to have(1).errors_on(:receivers)
        agent.user = users(:jane)
        expect(agent).to have(0).errors_on(:receivers)
      end

      it 'should not allow controller agents owned by other people' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)
        agent.controller_ids = [agents(:bob_status_agent).id]
        expect(agent).to have(0).errors_on(:controllers)
        agent.controller_ids = [agents(:jane_status_agent).id]
        expect(agent).to have(1).errors_on(:controllers)
        agent.user = users(:jane)
        expect(agent).to have(0).errors_on(:controllers)
      end

      it 'should not allow control target agents owned by other people' do
        agent = Agents::CannotBeScheduled.new(name: 'something')
        agent.user = users(:bob)
        agent.control_target_ids = [agents(:bob_status_agent).id]
        expect(agent).to have(0).errors_on(:control_targets)
        agent.control_target_ids = [agents(:jane_status_agent).id]
        expect(agent).to have(1).errors_on(:control_targets)
        agent.user = users(:jane)
        expect(agent).to have(0).errors_on(:control_targets)
      end

      it 'should not allow workflows owned by other people' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)

        agent.workflow_ids = [workflows(:bob_status).id]
        expect(agent).to have(0).errors_on(:workflows)

        agent.workflow_ids = [workflows(:bob_status).id, workflows(:jane_status).id]
        expect(agent).to have(1).errors_on(:workflows)

        agent.workflow_ids = [workflows(:jane_status).id]
        expect(agent).to have(1).errors_on(:workflows)

        agent.user = users(:jane)
        expect(agent).to have(0).errors_on(:workflows)
      end

      it 'validates keep_messages_for' do
        agent = Agents::SomethingSource.new(name: 'something')
        agent.user = users(:bob)
        expect(agent).to be_valid
        agent.keep_messages_for = nil
        expect(agent).to have(1).errors_on(:keep_messages_for)
        agent.keep_messages_for = 1000
        expect(agent).to have(1).errors_on(:keep_messages_for)
        agent.keep_messages_for = ''
        expect(agent).to have(1).errors_on(:keep_messages_for)
        agent.keep_messages_for = 5.days.to_i
        expect(agent).to be_valid
        agent.keep_messages_for = 0
        expect(agent).to be_valid
        agent.keep_messages_for = 365.days.to_i
        expect(agent).to be_valid

        # Rails seems to call to_i on the input. This guards against future changes to that behavior.
        agent.keep_messages_for = 'drop table;'
        expect(agent.keep_messages_for).to eq(0)
      end
    end

    describe 'cleaning up now-expired messages' do
      before do
        @time = '2014-01-01 01:00:00 +00:00'
        time_travel_to @time do
          @agent = Agents::SomethingSource.new(name: 'something')
          @agent.keep_messages_for = 5.days
          @agent.user = users(:bob)
          @agent.save!
          @message = @agent.create_message payload: { 'hello' => 'world' }
          expect(@message.expires_at.to_i).to be_within(2).of(5.days.from_now.to_i)
        end
      end

      describe 'when keep_messages_for has not changed' do
        it 'does nothing' do
          mock(@agent).update_message_expirations!.times(0)

          @agent.options[:foo] = 'bar1'
          @agent.save!

          @agent.options[:foo] = 'bar1'
          @agent.keep_messages_for = 5.days
          @agent.save!
        end
      end

      describe 'when keep_messages_for is changed' do
        it "updates messages' expires_at" do
          time_travel_to @time do
            expect {
              @agent.options[:foo] = 'bar1'
              @agent.keep_messages_for = 3.days
              @agent.save!
            }.to change { @message.reload.expires_at }
            expect(@message.expires_at.to_i).to be_within(2).of(3.days.from_now.to_i)
          end
        end

        it 'updates messages relative to their created_at' do
          @message.update_attribute :created_at, 2.days.ago
          expect(@message.reload.created_at.to_i).to be_within(2).of(2.days.ago.to_i)

          expect {
            @agent.options[:foo] = 'bar2'
            @agent.keep_messages_for = 3.days
            @agent.save!
          }.to change { @message.reload.expires_at }
          expect(@message.expires_at.to_i).to be_within(60 * 61).of(1.days.from_now.to_i) # The larger time is to deal with daylight savings
        end

        it 'nulls out expires_at when keep_messages_for is set to 0' do
          expect {
            @agent.options[:foo] = 'bar'
            @agent.keep_messages_for = 0
            @agent.save!
          }.to change { @message.reload.expires_at }.to(nil)
        end
      end
    end

    describe 'Agent.build_clone' do
      before do
        Message.delete_all
        @sender = Agents::SomethingSource.new(
          name: 'Agent (2)',
          options: { foo: 'bar2' },
          schedule: '17h'
        )
        @sender.user = users(:bob)
        @sender.save!
        @sender.create_message payload: {}
        @sender.create_message payload: {}
        expect(@sender.messages.count).to eq(2)

        @receiver = Agents::CannotBeScheduled.new(
          name: 'Agent',
          options: { foo: 'bar3' },
          keep_messages_for: 3.days
        )
        @receiver.user = users(:bob)
        @receiver.sources << @sender
        @receiver.memory[:test] = 1
        @receiver.save!
      end

      it 'should create a clone of a given agent for editing' do
        sender_clone = users(:bob).agents.build_clone(@sender)

        expect(sender_clone.attributes).to eq(Agent.new.attributes
          .update(@sender.slice(:user_id, :type,
                                :options, :schedule, :keep_messages_for))
          .update('name' => 'Agent (2) (2)', 'options' => { 'foo' => 'bar2' }))

        expect(sender_clone.source_ids).to eq([])

        receiver_clone = users(:bob).agents.build_clone(@receiver)

        expect(receiver_clone.attributes).to eq(Agent.new.attributes
          .update(@receiver.slice(:user_id, :type,
                                  :options, :schedule, :keep_messages_for))
          .update('name' => 'Agent (3)', 'options' => { 'foo' => 'bar3' }))

        expect(receiver_clone.source_ids).to eq([@sender.id])
      end
    end
  end

  describe '.trigger_web_request' do
    class Agents::WebRequestReceiver < Agent
      cannot_be_scheduled!
    end

    before do
      stub(Agents::WebRequestReceiver).valid_type?('Agents::WebRequestReceiver') { true }
    end

    context 'when .receive_web_request is defined' do
      before do
        @agent = Agents::WebRequestReceiver.new(name: 'something')
        @agent.user = users(:bob)
        @agent.save!

        def @agent.receive_web_request(params, method, format)
          memory['last_request'] = [params, method, format]
          ['Ok!', 200]
        end
      end

      it 'calls the .receive_web_request hook, updates last_web_request_at, and saves' do
        request = ActionDispatch::Request.new({
                                                'action_dispatch.request.request_parameters' => { some_param: 'some_value' },
                                                'REQUEST_METHOD' => 'POST',
                                                'HTTP_ACCEPT' => 'text/html'
                                              })

        @agent.trigger_web_request(request)
        expect(@agent.reload.memory['last_request']).to eq([{ 'some_param' => 'some_value' }, 'post', 'text/html'])
        expect(@agent.last_web_request_at.to_i).to be_within(1).of(Time.now.to_i)
      end
    end

    context 'when .receive_web_request is defined with just request' do
      before do
        @agent = Agents::WebRequestReceiver.new(name: 'something')
        @agent.user = users(:bob)
        @agent.save!

        def @agent.receive_web_request(request)
          memory['last_request'] = [request.params, request.method_symbol.to_s, request.format, { 'HTTP_X_CUSTOM_HEADER' => request.headers['HTTP_X_CUSTOM_HEADER'] }]
          ['Ok!', 200]
        end
      end

      it 'calls the .trigger_web_request with headers, and they get passed to .receive_web_request' do
        request = ActionDispatch::Request.new({
                                                'action_dispatch.request.request_parameters' => { some_param: 'some_value' },
                                                'REQUEST_METHOD' => 'POST',
                                                'HTTP_ACCEPT' => 'text/html',
                                                'HTTP_X_CUSTOM_HEADER' => 'foo'
                                              })

        @agent.trigger_web_request(request)
        expect(@agent.reload.memory['last_request']).to eq([{ 'some_param' => 'some_value' }, 'post', 'text/html', { 'HTTP_X_CUSTOM_HEADER' => 'foo' }])
        expect(@agent.last_web_request_at.to_i).to be_within(1).of(Time.now.to_i)
      end
    end
  end

  describe 'scopes' do
    describe 'of_type' do
      it 'should accept classes' do
        agents = Agent.of_type(Agents::WebsiteAgent)
        expect(agents).to include(agents(:bob_website_agent))
        expect(agents).to include(agents(:jane_website_agent))
        expect(agents).not_to include(agents(:bob_status_agent))
      end

      it 'should accept strings' do
        agents = Agent.of_type('Agents::WebsiteAgent')
        expect(agents).to include(agents(:bob_website_agent))
        expect(agents).to include(agents(:jane_website_agent))
        expect(agents).not_to include(agents(:bob_status_agent))
      end

      it 'should accept instances of an Agent' do
        agents = Agent.of_type(agents(:bob_website_agent))
        expect(agents).to include(agents(:bob_website_agent))
        expect(agents).to include(agents(:jane_website_agent))
        expect(agents).not_to include(agents(:bob_status_agent))
      end
    end
  end

  describe '#create_message' do
    describe 'when the agent has keep_messages_for set' do
      before do
        expect(agents(:jane_status_agent).keep_messages_for).to be > 0
      end

      it 'sets expires_at on created messages' do
        message = agents(:jane_status_agent).create_message payload: { 'hi' => 'there' }
        expect(message.expires_at.to_i).to be_within(5).of(agents(:jane_status_agent).keep_messages_for.seconds.from_now.to_i)
      end
    end

    describe 'when the agent does not have keep_messages_for set' do
      before do
        expect(agents(:jane_website_agent).keep_messages_for).to eq(0)
      end

      it 'does not set expires_at on created messages' do
        message = agents(:jane_website_agent).create_message payload: { 'hi' => 'there' }
        expect(message.expires_at).to be_nil
      end
    end
  end

  describe '.last_checked_message_id' do
    it 'should be updated by setting drop_pending_messages to true' do
      agent = agents(:bob_notifier_agent)
      agent.last_checked_message_id = nil
      agent.save!
      agent.update!(drop_pending_messages: true)
      expect(agent.reload.last_checked_message_id).to eq(Message.maximum(:id))
    end

    it 'should not affect a virtual attribute drop_pending_messages' do
      agent = agents(:bob_notifier_agent)
      agent.update!(drop_pending_messages: true)
      expect(agent.reload.drop_pending_messages).to eq(false)
    end
  end
end

describe AgentDrop do
  def interpolate(string, agent)
    agent.interpolate_string(string, 'agent' => agent)
  end

  before do
    @wsa1 = Agents::WebsiteAgent.new(
      name: 'XKCD',
      options: {
        expected_update_period_in_days: 2,
        type: 'html',
        url: 'http://xkcd.com/',
        mode: 'on_change',
        extract: {
          url: { css: '#comic img', value: '@src' },
          title: { css: '#comic img', value: '@alt' }
        }
      },
      schedule: 'every_1h',
      keep_messages_for: 2.days
    )
    @wsa1.user = users(:bob)
    @wsa1.save!

    @wsa2 = Agents::WebsiteAgent.new(
      name: 'Dilbert',
      options: {
        expected_update_period_in_days: 2,
        type: 'html',
        url: 'http://dilbert.com/',
        mode: 'on_change',
        extract: {
          url: { css: '[id^=strip_enlarged_] img', value: '@src' },
          title: { css: '.STR_DateStrip', value: 'string(.)' }
        }
      },
      schedule: 'every_12h',
      keep_messages_for: 2.days
    )
    @wsa2.user = users(:bob)
    @wsa2.save!

    @efa = Agents::MessageFormattingAgent.new(
      name: 'Formatter',
      options: {
        instructions: {
          message: '{{agent.name}}: {{title}} {{url}}',
          agent: '{{agent.type}}'
        },
        mode: 'clean',
        matchers: [],
        skip_created_at: 'false'
      },
      keep_messages_for: 2.days
    )
    @efa.user = users(:bob)
    @efa.sources << @wsa1 << @wsa2
    @efa.memory[:test] = 1
    @efa.save!
    @wsa1.reload
    @wsa2.reload
  end

  it 'should be created via Agent#to_liquid' do
    expect(@wsa1.to_liquid.class).to be(AgentDrop)
    expect(@wsa2.to_liquid.class).to be(AgentDrop)
    expect(@efa.to_liquid.class).to be(AgentDrop)
  end

  it 'should have .id, .type and .name' do
    t = '[{{agent.id}}]{{agent.type}}: {{agent.name}}'
    expect(interpolate(t, @wsa1)).to eq("[#{@wsa1.id}]WebsiteAgent: XKCD")
    expect(interpolate(t, @wsa2)).to eq("[#{@wsa2.id}]WebsiteAgent: Dilbert")
    expect(interpolate(t, @efa)).to eq("[#{@efa.id}]MessageFormattingAgent: Formatter")
  end

  it 'should have .options' do
    t = '{{agent.options.url}}'
    expect(interpolate(t, @wsa1)).to eq('http://xkcd.com/')
    expect(interpolate(t, @wsa2)).to eq('http://dilbert.com/')
    expect(interpolate('{{agent.options.instructions.message}}',
                       @efa)).to eq('{{agent.name}}: {{title}} {{url}}')
  end

  it 'should have .sources' do
    t = '{{agent.sources.size}}: {{agent.sources | map:"name" | join:", "}}'
    expect(interpolate(t, @wsa1)).to eq('0: ')
    expect(interpolate(t, @wsa2)).to eq('0: ')
    expect(interpolate(t, @efa)).to eq('2: XKCD, Dilbert')

    t = '{{agent.sources.first.name}}..{{agent.sources.last.name}}'
    expect(interpolate(t, @wsa1)).to eq('..')
    expect(interpolate(t, @wsa2)).to eq('..')
    expect(interpolate(t, @efa)).to eq('XKCD..Dilbert')

    t = '{{agent.sources[1].name}}'
    expect(interpolate(t, @efa)).to eq('Dilbert')
  end

  it 'should have .receivers' do
    t = '{{agent.receivers.size}}: {{agent.receivers | map:"name" | join:", "}}'
    expect(interpolate(t, @wsa1)).to eq('1: Formatter')
    expect(interpolate(t, @wsa2)).to eq('1: Formatter')
    expect(interpolate(t, @efa)).to eq('0: ')
  end

  it 'should have .working' do
    stub(@wsa1).working? { false }
    stub(@wsa2).working? { true }
    stub(@efa).working? { false }

    t = '{% if agent.working %}healthy{% else %}unhealthy{% endif %}'
    expect(interpolate(t, @wsa1)).to eq('unhealthy')
    expect(interpolate(t, @wsa2)).to eq('healthy')
    expect(interpolate(t, @efa)).to eq('unhealthy')
  end

  it 'should have .url' do
    t = '{{ agent.url }}'
    expect(interpolate(t, @wsa1)).to match(%r{http:\/\/localhost(?::\d+)?\/agents\/#{@wsa1.id}})
    expect(interpolate(t, @wsa2)).to match(%r{http:\/\/localhost(?::\d+)?\/agents\/#{@wsa2.id}})
    expect(interpolate(t, @efa)).to  match(%r{http:\/\/localhost(?::\d+)?\/agents\/#{@efa.id}})
  end
end
