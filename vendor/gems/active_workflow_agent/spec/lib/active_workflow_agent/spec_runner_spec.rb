require 'spec_helper'

describe ActiveWorkflowAgent::SpecRunner do
  unless defined?(Bundler)
    class Bundler; def self.with_clean_env; yield end end
  end

  let(:runner) {ActiveWorkflowAgent::SpecRunner.new }

  it "detects the gem name" do
    expect(runner.gem_name).to eq('active_workflow_agent')
  end

  context '#shell_out' do
    it 'does not output anything without a specifing message' do
      expect(runner).not_to receive(:puts)
      runner.shell_out('pwd')
    end

    it "outputs the message and status information" do
      output = capture(:stdout) { runner.shell_out('pwd', 'Testing') }
      expect(output).to include('Testing')
      expect(output).to include('OK')
      expect(output).not_to include('FAIL')
    end

    it "output the called command on failure" do
      output = capture(:stdout) {
        expect { runner.shell_out('false', 'Testing') }.to raise_error(RuntimeError)
      }
      expect(output).to include('Testing')
      expect(output).to include('FAIL')
      expect(output).not_to include('OK')

    end
  end
end
