module DotHelper
  def render_agents_diagram(agents, workflow)
    if (command = ENV['GRAPHVIZ_DOT'] || 'dot') &&
       (svg = IO.popen([command, *%w[-Tsvg -q1 -o/dev/stdout /dev/stdin]], 'w+') { |dot|
                dot.print agents_dot(agents, workflow)
                dot.close_write
                dot.read
              } rescue false)
      decorate_svg(svg, agents, workflow).html_safe
    else
      message = "Can't display diagram. You may need to set GRAPHVIZ_DOT environment variable to the correct dot executable."
      "<div class='alert alert-danger'>#{message}</div>".html_safe
    end
  end

  class DotDrawer
    def initialize(vars = {})
      @dot = ''
      @vars = vars.symbolize_keys
    end

    def method_missing(var, *args)
      @vars.fetch(var) { super }
    end

    def to_s
      @dot
    end

    def self.draw(*args, &block)
      drawer = new(*args)
      drawer.instance_exec(&block)
      drawer.to_s
    end

    def raw(string)
      @dot << string
    end

    ENDL = ';'.freeze

    def endl
      @dot << ENDL
    end

    def escape(string)
      # Backslash escaping seems to work for the backslash itself,
      # though it's not documented in the DOT language docs.
      string.gsub(/[\\"\n]/,
                  '\\' => '\\\\',
                  '"' => '\\"',
                  "\n" => '\\n')
    end

    def id(value)
      case string = value.to_s
      when /\A(?!\d)\w+\z/, /\A(?:\.\d+|\d+(?:\.\d*)?)\z/
        raw string
      else
        raw '"'
        raw escape(string)
        raw '"'
      end
    end

    def ids(values)
      values.each_with_index { |id, i|
        raw ' ' if i > 0
        id id
      }
    end

    def attr_list(attrs = nil)
      return if attrs.nil?
      attrs = attrs.select { |key, value| value.present? }
      return if attrs.empty?
      raw '['
      attrs.each_with_index { |(key, value), i|
        raw ',' if i > 0
        id key
        raw '='
        id value
      }
      raw ']'
    end

    def node(id, attrs = nil)
      id id
      attr_list attrs
      endl
    end

    def edge(from, to, attrs = nil, op = '->')
      id from
      raw op
      id to
      attr_list attrs
      endl
    end

    def statement(ids, attrs = nil)
      ids Array(ids)
      attr_list attrs
      endl
    end

    def block(*ids, &block)
      ids ids
      raw '{'
      block.call
      raw '}'
    end
  end

  private

  def draw(vars = {}, &block)
    DotDrawer.draw(vars, &block)
  end

  def agents_dot(agents, workflow=nil)
    draw(agents: agents,
         agent_id: ->(agent) { 'a%d' % agent.id },
         agent_label: lambda { |agent|
           agent.name.gsub(/(.{20}\S*)\s+/) {
             # Fold after every 20+ characters
             $1 + "\n"
           }
         },
         agent_url: ->(agent) { agent_path(agent.id, params: { workflow_id: workflow }) }) {
      @disabled = '#999999'

      def agent_node(agent)
        node(agent_id[agent],
             label: agent_label[agent],
             tooltip: agent.short_type.titleize,
             URL: agent_url[agent],
             style: ('rounded,dashed' if agent.unavailable?),
             color: (@disabled if agent.unavailable?),
             fontcolor: (@disabled if agent.unavailable?))
      end

      def agent_edge(agent, receiver)
        edge(agent_id[agent],
             agent_id[receiver],
             label: (" #{agent.control_action}s " if agent.can_control_other_agents?),
             arrowhead: ('empty' if agent.can_control_other_agents?),
             color: (@disabled if agent.unavailable? || receiver.unavailable?))
      end

      block('digraph', 'Agent Message Flow') {
        raw("bgcolor=transparent\n")
        raw("truecolor=true\n")
        statement 'graph', overlap: 'false'
        statement 'node',
                  shape: 'box',
                  style: 'rounded',
                  fontsize: 10,
                  fontname: 'SourceSansPro'

        statement 'edge',
                  fontsize: 10,
                  fontname: 'SourceSansPro'

        agents.each.with_index { |agent, index|
          agent_node(agent)

          [
            *agent.receivers,
            *(agent.control_targets if agent.can_control_other_agents?)
          ].each { |receiver|
            agent_edge(agent, receiver) if agents.include?(receiver)
          }
        }
      }
    }
  end

  def decorate_svg(xml, agents, workflow)
    svg = Nokogiri::XML(xml).at('svg')

    Nokogiri::HTML::Document.new.tap { |doc|
      doc << root = Nokogiri::XML::Node.new('div', doc) { |div|
        div['class'] = 'agent-diagram'
      }

      svg['class'] = 'diagram'

      root << svg
      root << overlay_container = Nokogiri::XML::Node.new('div', doc) { |div|
        div['class'] = 'overlay-container'
      }
      overlay_container << overlay = Nokogiri::XML::Node.new('div', doc) { |div|
        div['class'] = 'overlay'
      }

      svg.xpath('//xmlns:g[@class="node"]', svg.namespaces).each { |node|
        agent_id = (node.xpath('./xmlns:title/text()', svg.namespaces).to_s[/\d+/] or next).to_i
        agent = agents.find { |a| a.id == agent_id }
        node['data-agent-id'] = agent_id

        count = agent.messages_count

        overlay << Nokogiri::XML::Node.new('a', doc) { |badge|
          badge['id'] = id = 'b%d' % agent_id
          badge['class'] = 'badge'
          badge['style'] = 'display: none'
          badge['href'] = agent_path(agent, params: { tab: 'messages', workflow_id: workflow })
          badge.content = count.to_s

          node['data-badge-id'] = id
        }
      }
      # See also: app/assets/diagram.js
    }.at('div.agent-diagram').to_s
  end
end
