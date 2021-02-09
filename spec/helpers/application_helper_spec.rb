require 'rails_helper'

describe ApplicationHelper do
  describe '#icon_tag' do
    it 'returns a FontAwesome icon element' do
      icon = icon_tag('fa-copy')
      expect(icon).to be_html_safe
      expect(Nokogiri(icon).at('i.fa.fa-copy')).to be_a Nokogiri::XML::Element
    end

    it 'returns a FontAwesome icon element' do
      icon = icon_tag('fa-copy', class: 'text-info')
      expect(icon).to be_html_safe
      expect(Nokogiri(icon).at('i.fa.fa-copy.text-info')).to be_a Nokogiri::XML::Element
    end

    it 'adds html attributes' do
      icon = icon_tag('fa-copy', class: 'text-info', 'data-toggle' => 'tooltip', title: 'Text')
      expect(icon).to be_html_safe
      expect(Nokogiri(icon).at('i').attr('data-toggle')).to eq('tooltip')
      expect(Nokogiri(icon).at('i').attr('title')).to eq('Text')
    end
  end

  describe '#nav_link' do
    it 'returns a nav link' do
      stub(self).current_page?('/things') { false }
      nav = nav_link('Things', '/things')
      a = Nokogiri(nav).at('li:not(.active) > a[href="/things"]')
      expect(a.text.strip).to eq('Things')
    end

    it 'returns an active nav link' do
      stub(self).current_page?('/things') { true }
      nav = nav_link('Things', '/things')
      expect(nav).to be_html_safe
      a = Nokogiri(nav).at('li.active > a[href="/things"]')
      expect(a).to be_a Nokogiri::XML::Element
      expect(a.text.strip).to eq('Things')
    end

    describe 'with block' do
      it 'returns a nav link with menu' do
        stub(self).current_page?('/things') { false }
        stub(self).current_page?('/things/stuff') { false }
        nav = nav_link('Things', '/things') { nav_link('Stuff', '/things/stuff') }
        expect(nav).to be_html_safe
        a0 = Nokogiri(nav).at('li.dropdown:not(.active) > a[href="/things"]')
        expect(a0).to be_a Nokogiri::XML::Element
        expect(a0.text.strip).to eq('Things')
        a1 = Nokogiri(nav).at('li.dropdown:not(.active) > li:not(.active) > a[href="/things/stuff"]')
        expect(a1).to be_a Nokogiri::XML::Element
        expect(a1.text.strip).to eq('Stuff')
      end

      it 'returns an active nav link with menu' do
        stub(self).current_page?('/things') { true }
        stub(self).current_page?('/things/stuff') { false }
        nav = nav_link('Things', '/things') { nav_link('Stuff', '/things/stuff') }
        expect(nav).to be_html_safe
        a0 = Nokogiri(nav).at('li.dropdown.active > a[href="/things"]')
        expect(a0).to be_a Nokogiri::XML::Element
        expect(a0.text.strip).to eq('Things')
        a1 = Nokogiri(nav).at('li.dropdown.active > li:not(.active) > a[href="/things/stuff"]')
        expect(a1).to be_a Nokogiri::XML::Element
        expect(a1.text.strip).to eq('Stuff')
      end

      it 'returns an active nav link with menu when on a child page' do
        stub(self).current_page?('/things') { false }
        stub(self).current_page?('/things/stuff') { true }
        nav = nav_link('Things', '/things') { nav_link('Stuff', '/things/stuff') }
        expect(nav).to be_html_safe
        a0 = Nokogiri(nav).at('li.dropdown.active > a[href="/things"]')
        expect(a0).to be_a Nokogiri::XML::Element
        expect(a0.text.strip).to eq('Things')
        a1 = Nokogiri(nav).at('li.dropdown.active > li:not(.active) > a[href="/things/stuff"]')
        expect(a1).to be_a Nokogiri::XML::Element
        expect(a1.text.strip).to eq('Stuff')
      end
    end
  end

  describe '#yes_no' do
    it 'returns a label "Yes" if any truthy value is given' do
      [true, Object.new].each { |value|
        label = yes_no(value)
        expect(label).to be_html_safe
        expect(Nokogiri(label).text).to eq 'Yes'
      }
    end

    it 'returns a label "No" if any falsy value is given' do
      [false, nil].each { |value|
        label = yes_no(value)
        expect(label).to be_html_safe
        expect(Nokogiri(label).text).to eq 'No'
      }
    end
  end

  describe '#agent_status' do
    before do
      @agent = agents(:jane_website_agent)
    end

    it 'returns a label "Disabled" if a given agent is disabled' do
      stub(@agent).disabled? { true }
      label = agent_status(@agent)
      expect(label).to eq 'Disabled'
    end

    it 'returns a label "Enabled" if a given agent is enabled' do
      label = agent_status(@agent)
      expect(label).to eq 'Enabled'
    end
  end

  describe '#agent_issues' do
    before do
      @agent = agents(:jane_website_agent)
    end

    it 'returns a text "Recent error (check logs)"' do
      stub(@agent).issue_recent_errors? { true }
      expect(agent_issues(@agent)).to include 'Recent error (check logs)'
    end

    it 'returns a text "Error during check/receive (check logs)"' do
      stub(@agent).issue_error_during_last_operation? { true }
      expect(agent_issues(@agent)).to include 'Error during check/receive (check logs)'
    end

    it 'returns a text "No new messages created within N days"' do
      @agent.options['expected_update_period_in_days'] = 5
      stub(@agent).issue_update_timeout? { true }
      expect(agent_issues(@agent)).to include 'No new messages created within 5 days'
    end

    it 'returns a text "No messages received within N days"' do
      @agent.options['expected_receive_period_in_days'] = 5
      stub(@agent).issue_receive_timeout? { true }
      expect(agent_issues(@agent)).to include 'No messages received within 5 days'
    end

    it 'returns a text "Gems missing"' do
      stub(@agent).issue_dependencies_missing? { true }
      expect(agent_issues(@agent)).to include 'Gems missing'
    end
  end

  describe '#highlighted?' do
    it 'understands hl=6-8' do
      stub(params).[](:hl) { '6-8' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [6, 7, 8]
    end

    it 'understands hl=1,3-4,9' do
      stub(params).[](:hl) { '1,3-4,9' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [1, 3, 4, 9]
    end

    it 'understands hl=8-' do
      stub(params).[](:hl) { '8-' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [8, 9, 10]
    end

    it 'understands hl=-2' do
      stub(params).[](:hl) { '-2' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [1, 2]
    end

    it 'understands hl=-' do
      stub(params).[](:hl) { '-' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end

    it 'is OK with no hl' do
      stub(params).[](:hl) { nil }
      expect((1..10).select { |i| highlighted?(i) }).to be_empty
    end
  end
end
