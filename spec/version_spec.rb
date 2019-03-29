require 'rails_helper'

module ActiveWorkflow
  describe 'application version' do
    it 'has version number set correctly' do
      commited_version = Gem::Version.new(open('VERSION').read())
      expect(Gem::Version.new(Application::VERSION)).to eq(commited_version)
    end
  end
end
