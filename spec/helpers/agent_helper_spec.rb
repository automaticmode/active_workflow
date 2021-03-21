require 'rails_helper'

describe AgentHelper do
  describe '#agent_short_description' do
    subject(:short_description) do
      AgentHelper.agent_short_description(agent)
    end

    let(:agent) do
      Agent.new.tap do |a|
        stub(a).description { description }
      end
    end

    context 'when description is simple text' do
      let(:description) { 'Good!' }
      it { is_expected.to eq 'Good!' }
    end

    context 'When description is multi paragraph text' do
      let(:description) { "Good!\n\nLong text." }
      it { is_expected.to eq 'Good!' }
    end

    context 'When description starts with header' do
      let(:description) { "# Good!\n\nLong text." }
      it { is_expected.to eq 'Good!' }
    end

    context 'When description starts with h2' do
      let(:description) { "## Good!\n\nLong text." }
      it { is_expected.to eq 'Good!' }
    end

    context 'When description starts with a comment' do
      let(:description) { "<!-- Comment -->\nGood!" }
      it { is_expected.to eq 'Good!' }
    end

    context 'When description includes formatting/subtags' do
      let(:description) { "Good `agent` **here**!" }
      it { is_expected.to eq 'Good agent here!' }
    end
  end
end
