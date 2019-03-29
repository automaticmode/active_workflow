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

  def working(agent)
    if agent.disabled?
      link_to 'Disabled', agent_path(agent), class: 'badge badge-warning'
    elsif agent.dependencies_missing?
      content_tag :span, 'Missing Gems', class: 'badge badge-danger'
    elsif agent.working?
      content_tag :span, 'Yes', class: 'badge badge-success'
    else
      link_to 'No', agent_path(agent, tab: (agent.recent_error_logs? ? 'logs' : 'details')), class: 'badge badge-danger'
    end
  end

  def omniauth_provider_icon(provider)
    case provider.to_sym
    when :github, :dropbox
      icon_tag("fa-#{provider}")
    when :wunderlist
      icon_tag('fa-list')
    else
      icon_tag('fa-lock')
    end
  end

  def omniauth_provider_name(provider)
    t("devise.omniauth_providers.#{provider}")
  end

  def omniauth_button(provider)
    link_to [
      omniauth_provider_icon(provider),
      content_tag(:span, "Authenticate with #{omniauth_provider_name(provider)}")
    ].join.html_safe, user_omniauth_authorize_path(provider), class: "btn btn-primary btn-sm btn-service service-#{provider}"
  end

  def service_label_text(service)
    "#{omniauth_provider_name(service.provider)} - #{service.name}"
  end

  def service_label(service)
    return if service.nil?
    content_tag :span, [
      omniauth_provider_icon(service.provider),
      service_label_text(service)
    ].join.html_safe, class: "badge bagde-service service-#{service.provider}"
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

  private

  def user_omniauth_authorize_path(provider)
    send "user_#{provider}_omniauth_authorize_path"
  end
end
