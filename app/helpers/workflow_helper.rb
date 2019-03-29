module WorkflowHelper
  def style_colors(workflow)
    colors = {
      color: workflow.tag_fg_color || default_workflow_fg_color,
      background_color: workflow.tag_bg_color || default_workflow_bg_color
    }.map { |key, value| "#{key.to_s.dasherize}:#{value}" }.join(';')
  end

  def workflow_label(workflow, text = nil)
    text ||= workflow.name
    content_tag :span, text, class: 'badge workflow', style: style_colors(workflow)
  end

  def default_workflow_bg_color
    '#5BC0DE'
  end

  def default_workflow_fg_color
    '#FFFFFF'
  end
end
