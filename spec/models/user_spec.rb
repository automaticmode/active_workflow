require 'rails_helper'

describe User do
  let(:bob) { users(:bob) }

  context '#deactivate!' do
    it 'deactivates the user and all her agents' do
      agent = agents(:jane_website_agent)
      users(:jane).deactivate!
      agent.reload
      expect(agent.deactivated).to be_truthy
      expect(users(:jane).deactivated_at).not_to be_nil
    end
  end

  context '#activate!' do
    before do
      users(:bob).deactivate!
    end

    it 'activates the user and all his agents' do
      agent = agents(:bob_website_agent)
      users(:bob).activate!
      agent.reload
      expect(agent.deactivated).to be_falsy
      expect(users(:bob).deactivated_at).to be_nil
    end
  end

  context '#undefined_agent_types' do
    it 'returns an empty array when no agents are undefined' do
      expect(bob.undefined_agent_types).to be_empty
    end

    it 'returns the undefined agent types' do
      agent = agents(:bob_website_agent)
      agent.update_attribute(:type, 'Agents::UndefinedAgent')
      expect(bob.undefined_agent_types).to match_array(['Agents::UndefinedAgent'])
    end
  end

  context '#undefined_agents' do
    it 'returns an empty array when no agents are undefined' do
      expect(bob.undefined_agents).to be_empty
    end

    it 'returns the undefined agent types' do
      agent = agents(:bob_website_agent)
      agent.update_attribute(:type, 'Agents::UndefinedAgent')
      expect(bob.undefined_agents).not_to be_empty
      expect(bob.undefined_agents.first).to be_a(Agent)
    end
  end
end
