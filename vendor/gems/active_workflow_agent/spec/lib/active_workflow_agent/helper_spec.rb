require 'spec_helper'

describe ActiveWorkflowAgent::Helper do
  context '#open3' do
    it "returns the exit status and output of the command" do
      expect(ActiveWorkflowAgent::Helper).not_to receive(:print)
      (status, output) = ActiveWorkflowAgent::Helper.open3("pwd")
      expect(status).to eq(0)
      expect(output).to eq("#{Dir.pwd}\n")
    end

    it "return 1 as the status for failing command" do
      (status, output) = ActiveWorkflowAgent::Helper.open3("false")
      expect(status).to eq(1)
    end

    it "returns 1 when an IOError occurred" do
      expect(IO).to receive(:select).and_raise(IOError)
      (status, output) = ActiveWorkflowAgent::Helper.open3("pwd")
      expect(status).to eq(1)
      expect(output).to eq('IOError IOError')
    end
  end

  context '#exec' do
    it "returns the exit status and output of the command" do
      (status, output) = ActiveWorkflowAgent::Helper.exec("pwd")
      expect(status).to eq(0)
      expect(output).to eq('')
    end

    it "return 1 as the status for failing command" do
      (status, output) = ActiveWorkflowAgent::Helper.exec("false")
      expect(status).to eq(1)
    end
  end
end
