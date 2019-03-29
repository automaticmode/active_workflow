require 'spec_helper'

describe ActiveWorkflowAgent do
  it 'has a version number' do
    expect(ActiveWorkflowAgent::VERSION).not_to be nil
  end

  context '#load_tasks' do
    class Rake; end

    before(:each) do
      expect(Rake).to receive(:add_rakelib)
    end

    it 'sets default values for branch and remote' do
      ActiveWorkflowAgent.load_tasks
      expect(ActiveWorkflowAgent.branch).to eq('master')
      expect(ActiveWorkflowAgent.remote).to eq('https://github.com/automaticmode/active_workflow')
    end

    it "sets branch and remote based on the passed options" do
      ActiveWorkflowAgent.load_tasks(branch: 'test', remote: 'http://git.example.com')
      expect(ActiveWorkflowAgent.branch).to eq('test')
      expect(ActiveWorkflowAgent.remote).to eq('http://git.example.com')
    end
  end

  context '#require!' do
    before(:each) do
      ActiveWorkflowAgent.instance_variable_set(:@load_paths, [])
      ActiveWorkflowAgent.instance_variable_set(:@agent_paths, [])
    end

    it 'requires files passed to #load' do
      ActiveWorkflowAgent.load('/tmp/test.rb')
      expect(ActiveWorkflowAgent).to receive(:require).with('/tmp/test.rb')
      ActiveWorkflowAgent.require!
    end

    it 'requires files passwd to #register and assign adds the class name to Agents::TYPES' do
      class Agent; TYPES = []; end
      string_double= double('test_agent.rb', camelize: 'TestAgent')
      expect(File).to receive(:basename).and_return(string_double)
      ActiveWorkflowAgent.register('/tmp/test_agent.rb')
      expect(ActiveWorkflowAgent).to receive(:require).with('/tmp/test_agent.rb')
      ActiveWorkflowAgent.require!
      expect(Agent::TYPES).to eq(['Agents::TestAgent'])
    end
  end
end
