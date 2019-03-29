require 'rails_helper'

describe Workflow do
  let(:new_instance) { users(:bob).workflows.build(name: 'some workflow') }

  it_behaves_like HasGuid

  describe 'validations' do
    before do
      expect(new_instance).to be_valid
    end

    it 'validates the presence of name' do
      new_instance.name = ''
      expect(new_instance).not_to be_valid
    end

    it 'validates the presence of user' do
      new_instance.user = nil
      expect(new_instance).not_to be_valid
    end

    it 'validates tag_fg_color is hex color' do
      new_instance.tag_fg_color = '#N07H3X'
      expect(new_instance).not_to be_valid
      new_instance.tag_fg_color = '#BADA55'
      expect(new_instance).to be_valid
    end

    it 'allows nil tag_fg_color' do
      new_instance.tag_fg_color = nil
      expect(new_instance).to be_valid
    end

    it 'validates tag_bg_color is hex color' do
      new_instance.tag_bg_color = '#N07H3X'
      expect(new_instance).not_to be_valid
      new_instance.tag_bg_color = '#BADA55'
      expect(new_instance).to be_valid
    end

    it 'allows nil tag_bg_color' do
      new_instance.tag_bg_color = nil
      expect(new_instance).to be_valid
    end

    it 'only allows Agents owned by user' do
      new_instance.agent_ids = [agents(:bob_website_agent).id]
      expect(new_instance).to be_valid

      new_instance.agent_ids = [agents(:jane_website_agent).id]
      expect(new_instance).not_to be_valid
    end
  end

  describe 'counters' do
    it 'maintains a counter cache on user' do
      expect {
        new_instance.save!
      }.to change { users(:bob).reload.workflow_count }.by(1)

      expect {
        new_instance.destroy
      }.to change { users(:bob).reload.workflow_count }.by(-1)
    end
  end

  context '#shared_agents' do
    it 'is empty when no agents are shared' do
      shared_agents = workflows(:bob_status).shared_agents
      expect(shared_agents).to be_empty
    end

    it 'returns only shared agents' do
      shared_agent_ids = workflows(:jane_status).shared_agents.map(&:id).sort
      expect(shared_agent_ids).to eq([agents(:jane_status_agent).id])
    end
  end

  context '#unique_agents' do
    it 'equals agents when no agents are shared' do
      agent_ids        = workflows(:bob_status).agents.map(&:id).sort
      unique_agent_ids = workflows(:bob_status).send(:unique_agent_ids).sort
      expect(agent_ids).to eq(unique_agent_ids)
    end

    it 'includes only agents that are not present in two scnearios' do
      unique_agent_ids = workflows(:jane_status).send(:unique_agent_ids)
      expect(unique_agent_ids).to eq([agents(:jane_notifier_agent).id])
    end

    it 'returns no agents when all are also used in a different workflow' do
      expect(workflows(:jane_status_duplicate).send(:unique_agent_ids)).to eq([])
    end
  end

  context '#destroy_with_mode' do
    it 'only destroys the workflow when no mode is passed' do
      expect { workflows(:jane_status).destroy_with_mode('') }.not_to change(Agent, :count)
    end

    it "only destroys unique agents when 'unique_agents' is passed" do
      expect { workflows(:jane_status).destroy_with_mode('unique_agents') }.to change(Agent, :count).by(-1)
    end

    it "destroys all agents when 'all_agents' is passed" do
      expect { workflows(:jane_status).destroy_with_mode('all_agents') }.to change(Agent, :count).by(-2)
    end
  end
end
