require 'rails_helper'

describe Agents::JavaScriptAgent do
  before do
    @valid_params = {
      name: 'somename',
      options: {
        code: "Agent.check = function() { this.createMessage({ 'message': 'hi' }); };"
      }
    }

    @agent = Agents::JavaScriptAgent.new(@valid_params)
    @agent.user = users(:jane)
    @agent.save!
  end

  describe 'validations' do
    it "requires 'code'" do
      expect(@agent).to be_valid
      @agent.options['code'] = ''
      expect(@agent).not_to be_valid
      @agent.options.delete('code')
      expect(@agent).not_to be_valid
    end
  end

  describe 'executing code' do
    it 'works by default' do
      @agent.options = @agent.default_options
      @agent.options['make_message'] = true
      @agent.save!

      expect {
        expect {
          @agent.receive([messages(:bob_website_agent_message)])
          @agent.check
        }.not_to change { AgentLog.count }
      }.to change { Message.count }.by(2)
    end

    describe 'error handling' do
      it 'should log an error when V8 has issues' do
        @agent.options['code'] = 'syntax error!'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to raise_error
        }.to change { AgentLog.count }.by(1)
        expect(AgentLog.last.message).to match(/Unexpected identifier/)
        expect(AgentLog.last.level).to eq(4)
      end

      it 'should log an error when JavaScript throws' do
        @agent.options['code'] = 'Agent.check = function() { throw "oh no"; };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to raise_error
        }.to change { AgentLog.count }.by(1)
        expect(AgentLog.last.message).to match(/oh no/)
        expect(AgentLog.last.level).to eq(4)
      end
    end

    describe 'getMemory' do
      it "won't store NaNs" do
        @agent.options['code'] = 'Agent.check = function() { this.memory("foo", NaN); };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq('NaN') # string
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it 'it stores an Array' do
        @agent.options['code'] = 'Agent.check = function() {
          var arr = [1,2];
          this.memory("foo", arr);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq([1, 2])
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it 'it stores a Hash' do
        @agent.options['code'] = 'Agent.check = function() {
          var obj = {};
          obj["one"] = 1;
          obj["two"] = [1,2];
          this.memory("foo", obj);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq({ 'one' => 1, 'two' => [1, 2] })
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it 'it stores a nested Hash' do
        @agent.options['code'] = 'Agent.check = function() {
          var u = {};
          u["one"] = 1;
          u["two"] = 2;
          var obj = {};
          obj["three"] = 3;
          obj["four"] = u;
          this.memory("foo", obj);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq({ 'three' => 3, 'four' => { 'one' => 1, 'two' => 2 } })
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it 'it stores null' do
        @agent.options['code'] = 'Agent.check = function() {
          this.memory("foo", "test");
          this.memory("foo", null);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq(nil)
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it 'it stores false' do
        @agent.options['code'] = 'Agent.check = function() {
          this.memory("foo", "test");
          this.memory("foo", false);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq(false)
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end
    end

    describe 'setMemory' do
      it 'stores an object' do
        @agent.options['code'] = 'Agent.check = function() {
          var u = {};
          u["one"] = 1;
          u["two"] = 2;
          this.setMemory(u);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory).to eq({ 'one' => 1, 'two' => 2 })
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end
    end

    describe 'deleteKey' do
      it 'deletes a memory key' do
        @agent.memory = { foo: 'baz' }
        @agent.options['code'] = 'Agent.check = function() {
          this.deleteKey("foo");
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to be_nil
        expect { @agent.reload.memory }.not_to raise_error
      end

      it 'returns the string value of the deleted key' do
        @agent.memory = { foo: 'baz' }
        @agent.options['code'] = 'Agent.check = function() {
          this.createMessage({ message: this.deleteKey("foo")});
          };'
        @agent.save!
        @agent.check
        created_message = @agent.messages.last
        expect(created_message.payload).to eq('message' => 'baz')
      end

      it 'returns the hash value of the deleted key' do
        @agent.memory = { foo: { baz: 'test' }  }
        @agent.options['code'] = 'Agent.check = function() {
          this.createMessage({ message: this.deleteKey("foo")});
          };'
        @agent.save!
        @agent.check
        created_message = @agent.messages.last
        expect(created_message.payload).to eq('message' => { 'baz' => 'test' })
      end
    end

    describe 'creating messages' do
      it 'creates messages with this.createMessage in the JavaScript environment' do
        @agent.options['code'] = 'Agent.check = function() { this.createMessage({ message: "This is an message!", stuff: { foo: 5 } }); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to change { AgentLog.count }
        }.to change { Message.count }.by(1)
        created_message = @agent.messages.last
        expect(created_message.payload).to eq({ 'message' => 'This is an message!', 'stuff' => { 'foo' => 5 } })
      end
    end

    describe 'logging' do
      it 'can output AgentLogs with this.log and this.error in the JavaScript environment' do
        @agent.options['code'] = 'Agent.check = function() { this.log("woah"); this.error("WOAH!"); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to raise_error
        }.to change { AgentLog.count }.by(2)

        log1, log2 = AgentLog.last(2)

        expect(log1.message).to eq('woah')
        expect(log1.level).to eq(3)
        expect(log2.message).to eq('WOAH!')
        expect(log2.level).to eq(4)
      end
    end

    describe 'escaping and unescaping HTML' do
      it 'can escape and unescape html with this.escapeHtml and this.unescapeHtml in the javascript environment' do
        @agent.options['code'] = 'Agent.check = function() { this.createMessage({ escaped: this.escapeHtml(\'test \"escaping\" <characters>\'), unescaped: this.unescapeHtml(\'test &quot;unescaping&quot; &lt;characters&gt;\')}); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to change { AgentLog.count }
        }.to change { Message.count }.by(1)
        created_message = @agent.messages.last
        expect(created_message.payload).to eq({ 'escaped' => 'test &quot;escaping&quot; &lt;characters&gt;', 'unescaped' => 'test "unescaping" <characters>' })
      end
    end

    describe 'getting incoming message' do
      it 'can access incoming messages in the JavaScript enviroment via this.incomingMessage' do
        message = Message.new
        message.agent = agents(:bob_notifier_agent)
        message.payload = { data: 'Something you should know about' }
        message.save!
        message.reload

        @agent.options['code'] = <<-JS
          Agent.receive = function() {
            var message = this.incomingMessage();
            this.createMessage({ 'message': 'I got an message!', 'message_was': message.payload });
          }
        JS

        @agent.save!
        expect {
          expect {
            @agent.receive(messages(:bob_website_agent_message))
            @agent.receive(message)
          }.not_to change { AgentLog.count }
        }.to change { Message.count }.by(2)
        created_message = @agent.messages.first
        expect(created_message.payload).to eq({ 'message' => 'I got an message!', 'message_was' => { 'data' => 'Something you should know about' } })
      end
    end

    describe 'getting and setting memory, getting options' do
      it 'can access options via this.options and work with memory via this.memory' do
        @agent.options['code'] = <<-JS
          Agent.check = function() {
            if (this.options('make_message')) {
              var callCount = this.memory('callCount') || 0;
              this.memory('callCount', callCount + 1);
            }
          };
        JS

        @agent.save!

        expect {
          expect {
            @agent.check
            expect(@agent.memory['callCount']).not_to be_present

            @agent.options['make_message'] = true
            @agent.check
            expect(@agent.memory['callCount']).to eq(1)

            @agent.check
            expect(@agent.memory['callCount']).to eq(2)

            @agent.memory['callCount'] = 20
            @agent.check
            expect(@agent.memory['callCount']).to eq(21)
          }.not_to change { AgentLog.count }
        }.not_to change { Message.count }
      end
    end

    describe 'user credentials' do
      it 'can access an existing credential' do
        @agent.send(:set_credential, 'test', 'hello')
        @agent.options['code'] = 'Agent.check = function() { this.log(this.credential("test")); };'
        @agent.save!
        @agent.check
        expect(AgentLog.last.message).to eq('hello')
      end

      it 'will create a new credential' do
        @agent.options['code'] = 'Agent.check = function() { this.credential("test","1234"); };'
        @agent.save!
        expect {
          @agent.check
        }.to change(UserCredential, :count).by(1)
      end

      it 'updates an existing credential' do
        @agent.send(:set_credential, 'test', 1234)
        @agent.options['code'] = 'Agent.check = function() { this.credential("test","12345"); };'
        @agent.save!
        expect {
          @agent.check
        }.to change(UserCredential, :count).by(0)
        expect(@agent.user.user_credentials.last.credential_value).to eq('12345')
      end
    end
  end
end
