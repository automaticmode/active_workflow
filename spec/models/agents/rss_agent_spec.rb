require 'rails_helper'

describe Agents::RssAgent do
  before do
    @valid_options = {
      'expected_update_period_in_days' => '2',
      'url' => 'https://github.com/rails/rails/commits/master.atom'
    }

    stub_request(:any, /github.com/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/github_commits.atom')), status: 200)
    stub_request(:any, /bad.github.com/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/github_commits.atom')).gsub(/<link [^>]+\/>/, '<link/>'), status: 200)
    stub_request(:any, /SlickdealsnetFP/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/slickdeals.atom')), status: 200)
    stub_request(:any, /onethingwell.org/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/onethingwell.rss')), status: 200)
    stub_request(:any, /bad.onethingwell.org/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/onethingwell.rss')).gsub(/(?<=<link>)[^<]*/, ''), status: 200)
    stub_request(:any, /iso-8859-1/).to_return(body: File.binread(Rails.root.join('spec/data_fixtures/iso-8859-1.rss')), headers: { 'Content-Type' => 'application/rss+xml; charset=ISO-8859-1' }, status: 200)
    stub_request(:any, /podcast/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/podcast.rss')), status: 200)
    stub_request(:any, /youtube/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/youtube.xml')), status: 200)
  end

  let(:agent) do
    _agent = Agents::RssAgent.new(name: 'rss feed', options: @valid_options)
    _agent.user = users(:bob)
    _agent.save!
    _agent
  end

  it_behaves_like WebRequestConcern

  describe 'validations' do
    it 'should validate the presence of url' do
      agent.options['url'] = 'http://google.com'
      expect(agent).to be_valid

      agent.options['url'] = ['http://google.com', 'http://yahoo.com']
      expect(agent).to be_valid

      agent.options['url'] = ''
      expect(agent).not_to be_valid

      agent.options['url'] = nil
      expect(agent).not_to be_valid
    end

    it 'should validate the presence and numericality of expected_update_period_in_days' do
      agent.options['expected_update_period_in_days'] = '5'
      expect(agent).to be_valid

      agent.options['expected_update_period_in_days'] = 'wut?'
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = 0
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = nil
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = ''
      expect(agent).not_to be_valid
    end
  end

  describe 'emitting RSS messages' do
    it 'should emit items as messages for an Atom feed' do
      agent.options['include_feed_info'] = true
      agent.options['include_sort_info'] = true

      expect {
        agent.check
      }.to change { agent.messages.count }.by(20)

      first, *, last = agent.messages.last(20)
      [first, last].each do |message|
        expect(message.payload['feed']).to include({
                                                     'type' => 'atom',
                                                     'title' => 'Recent Commits to rails:master',
                                                     'url' => 'https://github.com/rails/rails/commits/master',
                                                     'links' => [
                                                       {
                                                         'type' => 'text/html',
                                                         'rel' => 'alternate',
                                                         'href' => 'https://github.com/rails/rails/commits/master'
                                                       },
                                                       {
                                                         'type' => 'application/atom+xml',
                                                         'rel' => 'self',
                                                         'href' => 'https://github.com/rails/rails/commits/master.atom'
                                                       }
                                                     ]
                                                   })
      end
      expect(first.payload['url']).to eq('https://github.com/rails/rails/commit/b343beba03722672b9bb827f8ce29c7c1c216406')
      expect(first.payload['urls']).to eq(['https://github.com/rails/rails/commit/b343beba03722672b9bb827f8ce29c7c1c216406'])
      expect(first.payload['links']).to eq([
                                             {
                                               'href' => 'https://github.com/rails/rails/commit/b343beba03722672b9bb827f8ce29c7c1c216406',
                                               'rel' => 'alternate',
                                               'type' => 'text/html'
                                             }
                                           ])
      expect(first.payload['authors']).to eq(['fxn (https://github.com/fxn)'])
      expect(first.payload['date_published']).to be_nil
      expect(first.payload['last_updated']).to eq('2019-05-02T11:45:56+00:00')
      expect(first.payload['sort_info']).to eq({ 'position' => 20, 'count' => 20 })
      expect(last.payload['url']).to eq('https://github.com/rails/rails/commit/0c152f2eb419306578115da2c9fa10af575bede7')
      expect(last.payload['urls']).to eq(['https://github.com/rails/rails/commit/0c152f2eb419306578115da2c9fa10af575bede7'])
      expect(last.payload['links']).to eq([
                                            {
                                              'href' => 'https://github.com/rails/rails/commit/0c152f2eb419306578115da2c9fa10af575bede7',
                                              'rel' => 'alternate',
                                              'type' => 'text/html'
                                            }
                                          ])
      expect(last.payload['authors']).to eq(['tenderlove (https://github.com/tenderlove)'])
      expect(last.payload['date_published']).to be_nil
      expect(last.payload['last_updated']).to eq('2019-04-30T22:25:49+00:00')
      expect(last.payload['sort_info']).to eq({ 'position' => 1, 'count' => 20 })
    end

    it 'should emit items as messages in the order specified in the messages_order option' do
      expect {
        agent.options['messages_order'] = ['{{title | replace_regex: "^[[:space:]]+", "" }}']
        agent.options['include_sort_info'] = true
        agent.check
      }.to change { agent.messages.count }.by(20)

      first, *, last = agent.messages.last(20)
      expect(first.payload['title'].strip).to eq('`@controller` may not be defined here, and if so, it causes a Ruby wa…')
      expect(first.payload['url']).to eq('https://github.com/rails/rails/commit/fef174f5c524edacbcad846d68400e7fe114a15a')
      expect(first.payload['urls']).to eq(['https://github.com/rails/rails/commit/fef174f5c524edacbcad846d68400e7fe114a15a'])
      expect(first.payload['sort_info']).to eq({ 'position' => 20, 'count' => 20 })
      expect(last.payload['title'].strip).to eq('Active Model release notes [ci skip]')
      expect(last.payload['url']).to eq('https://github.com/rails/rails/commit/21e0c88fc630467905781b5ddefe28a22d476f68')
      expect(last.payload['urls']).to eq(['https://github.com/rails/rails/commit/21e0c88fc630467905781b5ddefe28a22d476f68'])
      expect(last.payload['sort_info']).to eq({ 'position' => 1, 'count' => 20 })
    end

    it 'should emit items as messages for a FeedBurner RSS 2.0 feed' do
      agent.options['url'] = 'http://feeds.feedburner.com/SlickdealsnetFP?format=atom' # This is actually RSS 2.0 w/ Atom extension
      agent.options['include_feed_info'] = true
      agent.save!

      expect {
        agent.check
      }.to change { agent.messages.count }.by(79)

      first, *, last = agent.messages.last(79)
      expect(first.payload['feed']).to include({
                                                 'type' => 'rss',
                                                 'title' => 'SlickDeals.net',
                                                 'description' => 'Slick online shopping deals.',
                                                 'url' => 'http://slickdeals.net/'
                                               })
      # Feedjira extracts feedburner:origLink
      expect(first.payload['url']).to eq('http://slickdeals.net/permadeal/130160/green-man-gaming---pc-games-tomb-raider-game-of-the-year-6-hitman-absolution-elite-edition')
      expect(last.payload['feed']).to include({
                                                'type' => 'rss',
                                                'title' => 'SlickDeals.net',
                                                'description' => 'Slick online shopping deals.',
                                                'url' => 'http://slickdeals.net/'
                                              })
      expect(last.payload['url']).to eq('http://slickdeals.net/permadeal/129980/amazon---rearth-ringke-fusion-bumper-hybrid-case-for-iphone-6')
    end

    it 'should track ids and not re-emit the same item when seen again' do
      agent.check
      expect(agent.memory['seen_ids']).to eq(agent.messages.map { |e| e.payload['id'] })

      newest_id = agent.memory['seen_ids'][0]
      expect(agent.messages.first.payload['id']).to eq(newest_id)
      agent.memory['seen_ids'] = agent.memory['seen_ids'][1..-1] # forget the newest id

      expect {
        agent.check
      }.to change { agent.messages.count }.by(1)

      expect(agent.messages.first.payload['id']).to eq(newest_id)
      expect(agent.memory['seen_ids'][0]).to eq(newest_id)
    end

    it 'should truncate the seen_ids in memory at 500 items per default' do
      agent.memory['seen_ids'] = ['x'] * 490
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(500)
    end
    
    it 'should truncate the seen_ids in memory at amount of items configured in options' do
      agent.options['remembered_id_count'] = '600'
      agent.memory['seen_ids'] = ['x'] * 590
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(600)
    end
    
    it 'should truncate the seen_ids after configuring a lower limit of items when check is executed' do
      agent.memory['seen_ids'] = ['x'] * 600
      agent.options['remembered_id_count'] = '400'
      expect(agent.memory['seen_ids'].length).to eq(600)
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(400)
    end
    
    it 'should truncate the seen_ids at default after removing custom limit' do
      agent.options['remembered_id_count'] = '600'
      agent.memory['seen_ids'] = ['x'] * 590
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(600)

      agent.options.delete('remembered_id_count')
      agent.memory['seen_ids'] = ['x'] * 590
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(500)
    end

    it 'should support an array of URLs' do
      agent.options['url'] = ['https://github.com/rails/rails/commits/master.atom', 'http://feeds.feedburner.com/SlickdealsnetFP?format=atom']
      agent.save!

      expect {
        agent.check
      }.to change { agent.messages.count }.by(20 + 79)
    end

    it 'should fetch one message per run' do
      agent.options['url'] = ['https://github.com/rails/rails/commits/master.atom']

      agent.options['max_messages_per_run'] = 1
      agent.check
      expect(agent.messages.count).to eq(1)
    end

    it 'should fetch all messages per run' do
      agent.options['url'] = ['https://github.com/rails/rails/commits/master.atom']

      # <= 0 should ignore option and get all
      agent.options['max_messages_per_run'] = 0
      agent.check
      expect(agent.messages.count).to eq(20)

      agent.options['max_messages_per_run'] = -1
      expect {
        agent.check
      }.to_not change { agent.messages.count }
    end
  end

  context 'when no ids are available' do
    before do
      @valid_options['url'] = 'http://feeds.feedburner.com/SlickdealsnetFP?format=atom'
    end

    it 'calculates content MD5 sums' do
      expect {
        agent.check
      }.to change { agent.messages.count }.by(79)
      expect(agent.memory['seen_ids']).to eq(agent.messages.map { |e| Digest::MD5.hexdigest(e.payload['content']) })
    end
  end

  context 'parsing feeds' do
    before do
      @valid_options['url'] = 'http://onethingwell.org/rss'
    end

    it 'captures timestamps normalized in the ISO 8601 format' do
      agent.check
      first, *, third = agent.messages.take(3)
      expect(first.payload['date_published']).to eq('2015-08-20T17:00:10+01:00')
      expect(third.payload['date_published']).to eq('2015-08-20T13:00:07+01:00')
    end

    it 'captures multiple categories' do
      agent.check
      first, *, third = agent.messages.take(3)
      expect(first.payload['categories']).to eq(%w[csv crossplatform utilities])
      expect(third.payload['categories']).to eq(['web'])
    end

    it 'sanitizes HTML content' do
      agent.options['clean'] = true
      agent.check
      message = agent.messages.last
      expect(message.payload['content']).to eq('<a href="http://showgoers.tv/">Showgoers</a>: <blockquote> <p>Showgoers is a Chrome browser extension to synchronize your Netflix player with someone else so that you can co-watch the same movie on different computers with no hassle. Syncing up your player is as easy as sharing a URL.</p> </blockquote>')
      expect(message.payload['description']).to eq('<a href="http://showgoers.tv/">Showgoers</a>: <blockquote> <p>Showgoers is a Chrome browser extension to synchronize your Netflix player with someone else so that you can co-watch the same movie on different computers with no hassle. Syncing up your player is as easy as sharing a URL.</p> </blockquote>')
    end

    it 'captures an enclosure' do
      agent.check
      message = agent.messages.fourth
      expect(message.payload['enclosure']).to eq({ 'url' => 'http://c.1tw.org/images/2015/itsy.png', 'type' => 'image/png', 'length' => '48249' })
      expect(message.payload['image']).to eq('http://c.1tw.org/images/2015/itsy.png')
    end

    it 'ignores an empty author' do
      agent.check
      message = agent.messages.first
      expect(message.payload['authors']).to eq([])
    end

    context 'with an empty link in RSS' do
      before do
        @valid_options['url'] = 'http://bad.onethingwell.org/rss'
      end

      it 'does not leak :no_buffer' do
        agent.check
        message = agent.messages.first
        expect(message.payload['links']).to eq([])
      end
    end

    context 'with an empty link in RSS' do
      before do
        @valid_options['url'] = 'https://bad.github.com/rails/rails/commits/master.atom'
      end

      it 'does not leak :no_buffer' do
        agent.check
        message = agent.messages.first
        expect(message.payload['links']).to eq([])
      end
    end

    context 'with the encoding declared in both headers and the content' do
      before do
        @valid_options['url'] = 'http://example.org/iso-8859-1.rss'
      end

      it 'decodes the content properly' do
        agent.check
        message = agent.messages.first
        expect(message.payload['title']).to eq('Mëkanïk Zaïn')
      end

      it 'decodes the content properly with force_encoding specified' do
        @valid_options['force_encoding'] = 'iso-8859-1'
        agent.check
        message = agent.messages.first
        expect(message.payload['title']).to eq('Mëkanïk Zaïn')
      end
    end

    context 'with podcast elements' do
      before do
        @valid_options['url'] = 'http://example.com/podcast.rss'
        @valid_options['include_feed_info'] = true
      end

      let :feed_info do
        {
          'id' => nil,
          'type' => 'rss',
          'url' => 'http://www.example.com/podcasts/everything/index.html',
          'links' => [{ 'href' => 'http://www.example.com/podcasts/everything/index.html' }],
          'title' => 'All About Everything',
          'description' => 'All About Everything is a show about everything. Each week we dive into any subject known to man and talk about it as much as we can. Look for our podcast in the Podcasts app or in the iTunes Store',
          'copyright' => '℗ & © 2014 John Doe & Family',
          'generator' => nil,
          'icon' => nil,
          'authors' => [
            'John Doe'
          ],
          'date_published' => nil,
          'last_updated' => nil,
          'itunes_categories' => [
            'Technology', 'Gadgets',
            'TV & Film',
            'Arts', 'Food'
          ],
          'itunes_complete' => 'yes',
          'itunes_explicit' => 'no',
          'itunes_image' => 'http://example.com/podcasts/everything/AllAboutEverything.jpg',
          'itunes_owners' => ['John Doe <john.doe@example.com>'],
          'itunes_subtitle' => 'A show about everything',
          'itunes_summary' => 'All About Everything is a show about everything. Each week we dive into any subject known to man and talk about it as much as we can. Look for our podcast in the Podcasts app or in the iTunes Store',
          'language' => 'en-us'
        }
      end

      it 'is parsed correctly' do
        expect {
          agent.check
        }.to change { agent.messages.count }.by(4)

        expect(agent.messages.map(&:payload)).to match([
                                                         {
                                                           'feed' => feed_info,
                                                           'id' => 'http://example.com/podcasts/archive/aae20140601.mp3',
                                                           'url' => nil,
                                                           'urls' => [],
                                                           'links' => [],
                                                           'title' => 'Red,Whine, & Blue',
                                                           'description' => nil,
                                                           'content' => nil,
                                                           'image' => nil,
                                                           'enclosure' => {
                                                             'url' => 'http://example.com/podcasts/everything/AllAboutEverythingEpisode4.mp3',
                                                             'type' => 'audio/mpeg',
                                                             'length' => '498537'
                                                           },
                                                           'authors' => ['<Various>'],
                                                           'categories' => [],
                                                           'date_published' => '2016-03-11T01:15:00+00:00',
                                                           'last_updated' => '2016-03-11T01:15:00+00:00',
                                                           'itunes_duration' => '03:59',
                                                           'itunes_explicit' => 'no',
                                                           'itunes_image' => 'http://example.com/podcasts/everything/AllAboutEverything/Episode4.jpg',
                                                           'itunes_subtitle' => 'Red + Blue != Purple',
                                                           'itunes_summary' => 'This week we talk about surviving in a Red state if you are a Blue person. Or vice versa.'
                                                         },
                                                         {
                                                           'feed' => feed_info,
                                                           'id' => 'http://example.com/podcasts/archive/aae20140697.m4v',
                                                           'url' => nil,
                                                           'urls' => [],
                                                           'links' => [],
                                                           'title' => 'The Best Chili',
                                                           'description' => nil,
                                                           'content' => nil,
                                                           'image' => nil,
                                                           'enclosure' => {
                                                             'url' => 'http://example.com/podcasts/everything/AllAboutEverythingEpisode2.m4v',
                                                             'type' => 'video/x-m4v',
                                                             'length' => '5650889'
                                                           },
                                                           'authors' => ['Jane Doe'],
                                                           'categories' => [],
                                                           'date_published' => '2016-03-10T02:00:00-07:00',
                                                           'last_updated' => '2016-03-10T02:00:00-07:00',
                                                           'itunes_closed_captioned' => 'Yes',
                                                           'itunes_duration' => '04:34',
                                                           'itunes_explicit' => 'no',
                                                           'itunes_image' => 'http://example.com/podcasts/everything/AllAboutEverything/Episode3.jpg',
                                                           'itunes_subtitle' => 'Jane and Eric',
                                                           'itunes_summary' => 'This week we talk about the best Chili in the world. Which chili is better?'
                                                         },
                                                         {
                                                           'feed' => feed_info,
                                                           'id' => 'http://example.com/podcasts/archive/aae20140608.mp4',
                                                           'url' => nil,
                                                           'urls' => [],
                                                           'links' => [],
                                                           'title' => 'Socket Wrench Shootout',
                                                           'description' => nil,
                                                           'content' => nil,
                                                           'image' => nil,
                                                           'enclosure' => {
                                                             'url' => 'http://example.com/podcasts/everything/AllAboutEverythingEpisode2.mp4',
                                                             'type' => 'video/mp4',
                                                             'length' => '5650889'
                                                           },
                                                           'authors' => ['Jane Doe'],
                                                           'categories' => [],
                                                           'date_published' => '2016-03-09T13:00:00-05:00',
                                                           'last_updated' => '2016-03-09T13:00:00-05:00',
                                                           'itunes_duration' => '04:34',
                                                           'itunes_explicit' => 'no',
                                                           'itunes_image' => 'http://example.com/podcasts/everything/AllAboutEverything/Episode2.jpg',
                                                           'itunes_subtitle' => 'Comparing socket wrenches is fun!',
                                                           'itunes_summary' => 'This week we talk about metric vs. Old English socket wrenches. Which one is better? Do you really need both? Get all of your answers here.'
                                                         },
                                                         {
                                                           'feed' => feed_info,
                                                           'id' => 'http://example.com/podcasts/archive/aae20140615.m4a',
                                                           'url' => nil,
                                                           'urls' => [],
                                                           'links' => [],
                                                           'title' => 'Shake Shake Shake Your Spices',
                                                           'description' => nil,
                                                           'content' => nil,
                                                           'image' => nil,
                                                           'enclosure' => {
                                                             'url' => 'http://example.com/podcasts/everything/AllAboutEverythingEpisode3.m4a',
                                                             'type' => 'audio/x-m4a',
                                                             'length' => '8727310'
                                                           },
                                                           'authors' => ['John Doe'],
                                                           'categories' => [],
                                                           'date_published' => '2016-03-08T12:00:00+00:00',
                                                           'last_updated' => '2016-03-08T12:00:00+00:00',
                                                           'itunes_duration' => '07:04',
                                                           'itunes_explicit' => 'no',
                                                           'itunes_image' => 'http://example.com/podcasts/everything/AllAboutEverything/Episode1.jpg',
                                                           'itunes_subtitle' => 'A short primer on table spices',
                                                           'itunes_summary' => 'This week we talk about <a href="https://itunes/apple.com/us/book/antique-trader-salt-pepper/id429691295?mt=11">salt and pepper shakers</a>, comparing and contrasting pour rates, construction materials, and overall aesthetics. Come and join the party!'
                                                         }
                                                       ])
      end
    end

    context 'of YouTube' do
      before do
        @valid_options['url'] = 'http://example.com/youtube.xml'
        @valid_options['include_feed_info'] = true
      end

      it 'is parsed correctly' do
        expect {
          agent.check
        }.to change { agent.messages.count }.by(15)

        expect(agent.messages.first.payload).to match({
                                                        'feed' => {
                                                          'id' => 'yt:channel:UCoTLdfNePDQzvdEgIToLIUg',
                                                          'type' => 'atom',
                                                          'url' => 'https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg',
                                                          'links' => [
                                                            { 'href' => 'http://www.youtube.com/feeds/videos.xml?channel_id=UCoTLdfNePDQzvdEgIToLIUg', 'rel' => 'self' },
                                                            { 'href' => 'https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg', 'rel' => 'alternate' }
                                                          ],
                                                          'title' => 'SecDSM',
                                                          'description' => nil,
                                                          'copyright' => nil,
                                                          'generator' => nil,
                                                          'icon' => nil,
                                                          'authors' => ['SecDSM (https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg)'],
                                                          'date_published' => '2016-07-28T18:46:21+00:00',
                                                          'last_updated' => '2016-07-28T18:46:21+00:00'
                                                        },
                                                        'id' => 'yt:video:OCs1E0vP7Oc',
                                                        'authors' => ['SecDSM (https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg)'],
                                                        'categories' => [],
                                                        'content' => nil,
                                                        'date_published' => '2017-06-15T02:36:17+00:00',
                                                        'description' => nil,
                                                        'enclosure' => nil,
                                                        'image' => nil,
                                                        'last_updated' => '2017-06-15T02:36:17+00:00',
                                                        'links' => [
                                                          { 'href' => 'https://www.youtube.com/watch?v=OCs1E0vP7Oc', 'rel' => 'alternate' }
                                                        ],
                                                        'title' => 'SecDSM 2017 March - Talk 01',
                                                        'url' => 'https://www.youtube.com/watch?v=OCs1E0vP7Oc',
                                                        'urls' => ['https://www.youtube.com/watch?v=OCs1E0vP7Oc']
                                                      })
      end
    end
  end

  describe 'logging errors with the feed url' do
    it 'includes the feed URL when an exception is raised' do
      mock(Feedjira::Feed).parse(anything) { raise StandardError.new('Some error!') }
      expect(lambda {
        agent.check
      }).not_to raise_error
      expect(agent.logs.last.message).to match(%r[Failed to fetch https://github.com])
    end
  end
end
