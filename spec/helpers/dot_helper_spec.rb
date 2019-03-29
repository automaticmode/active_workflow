require 'rails_helper'

describe DotHelper do
  describe 'with example Agents' do
    class Agents::DotFoo < Agent
      default_schedule '14h'

      def check
        create_message payload: {}
      end
    end

    class Agents::DotBar < Agent
      cannot_be_scheduled!

      def check
        create_message payload: {}
      end
    end

    before do
      stub(Agents::DotFoo).valid_type?('Agents::DotFoo') { true }
      stub(Agents::DotBar).valid_type?('Agents::DotBar') { true }
    end

    describe '#decorate_svg' do
      # TODO: implement this unit test, or better yet - test render_agents_diagram.
    end

    describe '#agents_dot' do
      before do
        @agents = [
          @foo = Agents::DotFoo.new(name: 'foo').tap { |agent|
            agent.user = users(:bob)
            agent.save!
          },

          @bar1 = Agents::DotBar.new(name: 'bar1').tap { |agent|
            agent.user = users(:bob)
            agent.sources << @foo
            agent.save!
          },

          @bar2 = Agents::DotBar.new(name: 'bar2').tap { |agent|
            agent.user = users(:bob)
            agent.sources << @foo
            agent.disabled = true
            agent.save!
          },

          @bar3 = Agents::DotBar.new(name: 'bar3').tap { |agent|
            agent.user = users(:bob)
            agent.sources << @bar2
            agent.save!
          }
        ]
        @workflow = Workflow.new(id: 1, name: 'workflow',
                                 agents: @agents, user: users(:bob))
        @workflow.save!

        @foo.reload
        @bar2.reload

        # Fix the order of receivers
        @agents.each do |agent|
          stub.proxy(agent).receivers { |orig| orig.order(:id) }
        end
      end

      it 'generates a richer DOT script' do
        expect(agents_dot(@agents, @workflow)).to match(%r{
          \A
          digraph \x20 "Agent \x20 Message \x20 Flow" \{bgcolor=transparent\n
            truecolor=true\n
            (graph \[ [^\]]+ \];)?
            node \[ [^\]]+ \];
            edge \[ [^\]]+ \];
            (?<foo>\w+) \[label=foo,tooltip="Dot \x20 Foo",URL="#{Regexp.quote(agent_path(@foo, params: { workflow_id: @workflow }))}"\];
            \k<foo> -> (?<bar1>\w+);
            \k<foo> -> (?<bar2>\w+) \[color="\#999999"\];
            \k<bar1> \[label=bar1,tooltip="Dot \x20 Bar",URL="#{Regexp.quote(agent_path(@bar1, params: { workflow_id: @workflow }))}"\];
            \k<bar2> \[label=bar2,tooltip="Dot \x20 Bar",URL="#{Regexp.quote(agent_path(@bar2, params: { workflow_id: @workflow }))}",style="rounded,dashed",color="\#999999",fontcolor="\#999999"\];
            \k<bar2> -> (?<bar3>\w+) \[color="\#999999"\];
            \k<bar3> \[label=bar3,tooltip="Dot \x20 Bar",URL="#{Regexp.quote(agent_path(@bar3, params: { workflow_id: @workflow }))}"\];
          \}
          \z
        }x)
      end
    end
  end

  describe 'DotHelper::DotDrawer' do
    describe '#id' do
      it 'properly escapes double quotaion and backslash' do
        expect(DotHelper::DotDrawer.draw(foo: '') {
          id('hello\\"')
        }).to eq('"hello\\\\\\""')
      end
    end
  end
end
