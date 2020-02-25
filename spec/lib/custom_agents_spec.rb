require 'rails_helper'
require 'custom_agents'

RSpec.describe CustomAgents, mock: :rspec do
  class CustomAgentTestClass
    def self.register(config)
      config.description = 'description'
      config.display_name = 'display_name'
      config.default_options = { a: :b }
      config
    end

    def initialize(context); end

    def check; end
    def receive(msg); end
  end

  describe '.register' do
    it 'creates proxy class named accordingly' do
      CustomAgents.register(CustomAgentTestClass)
      expect(Object.const_defined?('Agents::ProxyCustomAgentTestClass')).to be true
    end

    it 'add proxy class to the agents types' do
      CustomAgents.register(CustomAgentTestClass)
      expect(::Agent::TYPES).to include('Agents::ProxyCustomAgentTestClass')
    end
  end

  describe 'ProxyClass' do
    subject do
      CustomAgents.register(CustomAgentTestClass)
      ::Agents::ProxyCustomAgentTestClass
    end

    it 'sets default schedule to never' do
      expect(subject.default_schedule).to eq 'never'
    end

    it 'sets description' do
      expect(subject.description).to eq 'description'
    end

    it 'sets display name' do
      expect(subject.display_name).to eq 'display_name'
    end

    it 'sets default options' do
      expect(subject.new.default_options).to eq(a: :b)
    end

    context 'instance' do
      let (:agent) do
        Object.new
      end

      before (:each) do
        stub(CustomAgentTestClass).new { agent }
      end

      it 'creates agent class with the context' do
        stub(agent).check
        mock(CustomAgentTestClass).new(instance_of(CustomAgentContext)) { agent }
        subject.new.check
      end

      describe 'check' do
        it 'calls agents check method' do
          mock(agent).check
          subject.new.check
        end
      end

      describe 'receive' do
        it 'calls agents receive method with all message' do
          mock(agent).receive('message1')
          mock(agent).receive('message2')
          subject.new.receive('message1')
          subject.new.receive('message2')
        end
      end
    end
  end
end
