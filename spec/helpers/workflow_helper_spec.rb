require 'rails_helper'

describe WorkflowHelper do
  let(:workflow) { users(:bob).workflows.build(name: 'Scene', tag_fg_color: '#AAAAAA', tag_bg_color: '#000000') }

  describe '#style_colors' do
    it 'returns a css style-formated version of the workflow foreground and background colors' do
      expect(style_colors(workflow)).to eq('color:#AAAAAA;background-color:#000000')
    end

    it 'defauls foreground and background colors' do
      workflow.tag_fg_color = nil
      workflow.tag_bg_color = nil
      expect(style_colors(workflow)).to eq('color:#FFFFFF;background-color:#5BC0DE')
    end
  end

  describe '#workflow_label' do
    it 'creates a workflow label with the workflow name' do
      expect(workflow_label(workflow)).to eq(
        '<span class="badge workflow" style="color:#AAAAAA;background-color:#000000">Scene</span>'
      )
    end

    it 'creates a workflow label with the given text' do
      expect(workflow_label(workflow, 'Other')).to eq(
        '<span class="badge workflow" style="color:#AAAAAA;background-color:#000000">Other</span>'
      )
    end
  end
end
