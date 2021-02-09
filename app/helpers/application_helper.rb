module ApplicationHelper
  def icon_tag(name, options = {})
    if dom_class = options[:class]
      dom_class = ' ' << dom_class
    end

    other_options = options.except(:class)

    raise "Unrecognized icon name: #{name}" unless name.start_with?('fa')
    attrs = other_options.map do |attr, value|
      "#{attr}=\"#{value}\""
    end.join(' ')
    "<i class='fa #{name}#{dom_class}' #{attrs}></i>".html_safe
  end

  def nav_link(name, path, options = {}, &block)
    link_options = options.dup()
    link_class = ['nav-link']
    if block
      link_options.merge!('data-toggle' => 'dropdown', 'role' => 'button')
      link_class.push('dropdown-toggle')
    end
    link_options.merge!(class: link_class.join(' '))
    content = link_to(name, path, link_options)
    active = current_page?(path)
    if block
      # Passing a block signifies that the link is a header of a hover
      # menu which contains what's in the block.
      begin
        @nav_in_menu = true
        @nav_link_active = active
        content += capture(&block)
        class_name = "dropdown #{@nav_link_active ? 'active' : ''}"
      ensure
        @nav_in_menu = @nav_link_active = false
      end
    else
      # Mark the menu header active if it contains the current page
      @nav_link_active ||= active if @nav_in_menu
      # An "active" menu item may be an eyesore, hence `!@nav_in_menu &&`.
      class_name = !@nav_in_menu && active ? 'active' : ''
    end
    li_class = ['nav-item', class_name]
    content_tag :li, content, class: li_class.join(' ')
  end

  def yes_no(bool)
    content_tag :span, bool ? 'Yes' : 'No', class: "badge #{bool ? 'badge-info' : ''}"
  end

  def agent_status(agent)
    if agent.disabled?
      'Disabled'
    else
      'Enabled'
    end
  end

  def agent_issues(agent)
    result = []
    result << 'Recent error (check logs)' if agent.issue_recent_errors?
    result << 'Error during check/receive (check logs)' if agent.issue_error_during_last_operation?
    if agent.issue_update_timeout?
      result << "No new messages created within #{agent.interpolated['expected_update_period_in_days']} days"
    end
    if agent.issue_receive_timeout?
      result << "No messages received within #{agent.interpolated['expected_receive_period_in_days']} days"
    end
    result << "Gems missing" if agent.issue_dependencies_missing?

    result
  end

  def highlighted?(id)
    @highlighted_ranges ||=
      case value = params[:hl].presence
      when String
        value.split(/,/).flat_map { |part|
          case part
          when /\A(\d+)\z/
            (part.to_i)..(part.to_i)
          when /\A(\d+)?-(\d+)?\z/
            ($1 ? $1.to_i : 1)..($2 ? $2.to_i : Float::INFINITY)
          else
            []
          end
        }
      else
        []
      end

    @highlighted_ranges.any? { |range| range.cover?(id) }
  end

  def agent_type_to_human(type)
    return type.display_name if type.respond_to?(:display_name) && type.display_name
    name = type.is_a?(Class) ? type.name : type
    name.gsub(/^.*::/, '').underscore.humanize.titleize
  end
end
