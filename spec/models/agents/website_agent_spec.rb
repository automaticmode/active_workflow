require 'rails_helper'

describe Agents::WebsiteAgent do
  describe 'checking without basic auth' do
    before do
      stub_request(:any, /xkcd/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/xkcd.html')),
                                           status: 200,
                                           headers: {
                                             'X-Status-Message' => 'OK'
                                           })
      stub_request(:any, /xkcd\.com\/index$/).to_return(status: 301,
                                                        headers: {
                                                          'Location' => 'http://xkcd.com/'
                                                        })
      @valid_options = {
        'name' => 'XKCD',
        'expected_update_period_in_days' => '2',
        'type' => 'html',
        'url' => 'http://xkcd.com',
        'mode' => 'on_change',
        'extract' => {
          'url' => { 'css' => '#comic img', 'value' => '@src' },
          'title' => { 'css' => '#comic img', 'value' => '@alt' },
          'hovertext' => { 'css' => '#comic img', 'value' => '@title' }
        }
      }
      @checker = Agents::WebsiteAgent.new(name: 'xkcd', options: @valid_options, keep_messages_for: 2.days)
      @checker.user = users(:bob)
      @checker.save!
    end

    it_behaves_like WebRequestConcern

    describe 'validations' do
      before do
        expect(@checker).to be_valid
      end

      it 'should validate the integer fields' do
        @checker.options['expected_update_period_in_days'] = '2'
        expect(@checker).to be_valid

        @checker.options['expected_update_period_in_days'] = 'nonsense'
        expect(@checker).not_to be_valid
      end

      it 'should validate the http_success_codes fields' do
        @checker.options['http_success_codes'] = [404]
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = [404, 404]
        expect(@checker).not_to be_valid

        @checker.options['http_success_codes'] = [404, '422']
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = [404.0]
        expect(@checker).not_to be_valid

        @checker.options['http_success_codes'] = ['not_a_code']
        expect(@checker).not_to be_valid

        @checker.options['http_success_codes'] = []
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = ''
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = false
        expect(@checker).to be_valid
      end

      it 'should validate uniqueness_look_back' do
        @checker.options['uniqueness_look_back'] = 'nonsense'
        expect(@checker).not_to be_valid

        @checker.options['uniqueness_look_back'] = '2'
        expect(@checker).to be_valid
      end

      it 'should validate mode' do
        @checker.options['mode'] = 'nonsense'
        expect(@checker).not_to be_valid

        @checker.options['mode'] = 'on_change'
        expect(@checker).to be_valid

        @checker.options['mode'] = 'all'
        expect(@checker).to be_valid

        @checker.options['mode'] = ''
        expect(@checker).to be_valid
      end

      it 'should validate the force_encoding option' do
        @checker.options['force_encoding'] = ''
        expect(@checker).to be_valid

        @checker.options['force_encoding'] = 'UTF-8'
        expect(@checker).to be_valid

        @checker.options['force_encoding'] = ['UTF-8']
        expect(@checker).not_to be_valid

        @checker.options['force_encoding'] = 'UTF-42'
        expect(@checker).not_to be_valid
      end

      context "in 'json' type" do
        it "should ensure that all extractions have a 'path'" do
          @checker.options['type'] = 'json'
          @checker.options['extract'] = {
            'url' => { 'foo' => 'bar' }
          }
          expect(@checker).to_not be_valid
          expect(@checker.errors_on(:base)).to include(/When type is json, all extractions must have a path attribute/)

          @checker.options['type'] = 'json'
          @checker.options['extract'] = {
            'url' => { 'path' => 'bar' }
          }
          expect(@checker).to be_valid
        end
      end
    end

    describe '#check' do
      it 'should check for changes (and update Message.expires_at)' do
        expect { @checker.check }.to change { Message.count }.by(1)
        message = Message.last
        sleep 2
        expect { @checker.check }.not_to change { Message.count }
        update_message = Message.last
        expect(update_message.expires_at).not_to eq(message.expires_at)
      end

      it 'should always save messages when in :all mode' do
        expect {
          @valid_options['mode'] = 'all'
          @checker.options = @valid_options
          @checker.check
          @checker.check
        }.to change { Message.count }.by(2)
      end

      it 'should take uniqueness_look_back into account during deduplication' do
        @valid_options['mode'] = 'all'
        @checker.options = @valid_options
        @checker.check
        @checker.check
        message = Message.last
        message.payload = '{}'
        message.save

        expect {
          @valid_options['mode'] = 'on_change'
          @valid_options['uniqueness_look_back'] = 2
          @checker.options = @valid_options
          @checker.check
        }.not_to change { Message.count }

        expect {
          @valid_options['mode'] = 'on_change'
          @valid_options['uniqueness_look_back'] = 1
          @checker.options = @valid_options
          @checker.check
        }.to change { Message.count }.by(1)
      end

      it 'should log an error if the number of results for a set of extraction patterns differs' do
        @valid_options['extract']['url']['css'] = 'div'
        @checker.options = @valid_options
        @checker.check
        expect(@checker.logs.first.message).to match(/Got an uneven number of matches/)
      end

      it 'should accept an array for url' do
        @valid_options['url'] = ['http://xkcd.com/1/', 'http://xkcd.com/2/']
        @checker.options = @valid_options
        expect { @checker.save! }.not_to raise_error;
        expect { @checker.check }.not_to raise_error;
      end

      it 'should parse messages from all urls in array' do
        expect {
          @valid_options['url'] = ['http://xkcd.com/', 'http://xkcd.com/']
          @valid_options['mode'] = 'all'
          @checker.options = @valid_options
          @checker.check
        }.to change { Message.count }.by(2)
      end

      it 'should follow unique rules when parsing array of urls' do
        expect {
          @valid_options['url'] = ['http://xkcd.com/', 'http://xkcd.com/']
          @checker.options = @valid_options
          @checker.check
        }.to change { Message.count }.by(1)
      end
    end

    describe 'http_success_codes' do
      it 'should allow scraping from a 404 result' do
        json = {
          'response' => {
            'version' => 2,
            'title' => 'hello!'
          }
        }
        zipped = ActiveSupport::Gzip.compress(json.to_json)
        stub_request(:any, /gzip/).to_return(body: zipped, headers: { 'Content-Encoding' => 'gzip' }, status: 404)
        site = {
          'name' => 'Some JSON Response',
          'expected_update_period_in_days' => '2',
          'type' => 'json',
          'url' => 'http://gzip.com',
          'mode' => 'on_change',
          'http_success_codes' => [404],
          'extract' => {
            'version' => { 'path' => 'response.version' }
          },
          # no unzip option
        }
        checker = Agents::WebsiteAgent.new(name: 'Weather Site', options: site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        message = Message.last
        expect(message.payload['version']).to eq(2)
      end
    end

    describe 'unzipping' do
      it 'should unzip automatically if the response has Content-Encoding: gzip' do
        json = {
          'response' => {
            'version' => 2,
            'title' => 'hello!'
          }
        }
        zipped = ActiveSupport::Gzip.compress(json.to_json)
        stub_request(:any, /gzip/).to_return(body: zipped, headers: { 'Content-Encoding' => 'gzip' }, status: 200)
        site = {
          'name' => 'Some JSON Response',
          'expected_update_period_in_days' => '2',
          'type' => 'json',
          'url' => 'http://gzip.com',
          'mode' => 'on_change',
          'extract' => {
            'version' => { 'path' => 'response.version' }
          },
          # no unzip option
        }
        checker = Agents::WebsiteAgent.new(name: 'Weather Site', options: site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        message = Message.last
        expect(message.payload['version']).to eq(2)
      end

      it 'should unzip with unzip option' do
        json = {
          'response' => {
            'version' => 2,
            'title' => 'hello!'
          }
        }
        zipped = ActiveSupport::Gzip.compress(json.to_json)
        stub_request(:any, /gzip/).to_return(body: zipped, status: 200)
        site = {
          'name' => 'Some JSON Response',
          'expected_update_period_in_days' => '2',
          'type' => 'json',
          'url' => 'http://gzip.com',
          'mode' => 'on_change',
          'extract' => {
            'version' => { 'path' => 'response.version' }
          },
          'unzip' => 'gzip'
        }
        checker = Agents::WebsiteAgent.new(name: 'Weather Site', options: site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        message = Message.last
        expect(message.payload['version']).to eq(2)
      end

      it 'should either avoid or support a raw deflate stream (#1018)' do
        stub_request(:any, /deflate/).with(headers: { 'Accept-Encoding' => /\A(?!.*deflate)/ })
                                     .to_return(body: 'hello',
                                                status: 200)
        stub_request(:any, /deflate/).with(headers: { 'Accept-Encoding' => /deflate/ })
                                     .to_return(body: "\xcb\x48\xcd\xc9\xc9\x07\x00\x06\x2c".b,
                                                headers: { 'Content-Encoding' => 'deflate' },
                                                status: 200)

        site = {
          'name' => 'Some Response',
          'expected_update_period_in_days' => '2',
          'type' => 'text',
          'url' => 'http://deflate',
          'mode' => 'on_change',
          'extract' => {
            'content' => { 'regexp' => '.+', 'index' => 0 }
          }
        }
        checker = Agents::WebsiteAgent.new(name: 'Deflate Test', options: site)
        checker.user = users(:bob)
        checker.save!

        expect {
          checker.check
        }.to change { Message.count }.by(1)
        message = Message.last
        expect(message.payload['content']).to eq('hello')
      end
    end

    describe 'encoding' do
      let :thinking do
        "\u{601d}\u{8003}"
      end

      let :odin do
        "\u{d3}\u{f0}inn"
      end

      let :url do
        'http://encoding-test.example.com/'
      end

      let :content_type do
        raise 'define me'
      end

      let :body do
        raise 'define me'
      end

      before do
        stub_request(:any, url).to_return(
          headers: {
            'Content-Type' => content_type
          },
          body: body.b,
          status: 200
        )
      end

      let :options do
        {
          'name' => 'Some agent',
          'expected_update_period_in_days' => '2',
          'url' => url,
          'mode' => 'on_change'
        }
      end

      let :checker do
        Agents::WebsiteAgent.create!(name: 'Encoding Checker', options: options) { |agent|
          agent.user = users(:bob)
        }
      end

      context 'with no encoding information' do
        context 'for a JSON file' do
          let :content_type do
            'application/json'
          end

          let :body do
            {
              value: thinking
            }.to_json
          end

          let :options do
            super().merge(
              'type' => 'json',
              'extract' => {
                'value' => { 'path' => 'value' }
              }
            )
          end

          it 'should be assumed to be UTF-8' do
            expect { checker.check }.to change { Message.count }.by(1)
            message = Message.last
            expect(message.payload['value']).to eq(thinking)
          end
        end

        context 'for an HTML file' do
          let :content_type do
            'text/html'
          end

          let :options do
            super().merge(
              'type' => 'html',
              'extract' => {
                'value' => { 'css' => 'title', 'value' => 'string(.)' }
              }
            )
          end

          context 'with a charset in the header' do
            let :content_type do
              super() + '; charset=iso-8859-1'
            end

            let :body do
              <<~HTML.encode(Encoding::ISO_8859_1)
                <!DOCTYPE html>
                <title>#{odin}</title>
                <p>Hello, world.
              HTML
            end

            it 'should be detected from it' do
              expect { checker.check }.to change { Message.count }.by(1)
              message = Message.last
              expect(message.payload['value']).to eq(odin)
            end
          end

          context 'with no charset in the header' do
            let :body do
              <<~HTML.encode(Encoding::ISO_8859_1)
                <!DOCTYPE html>
                <meta charset="iso-8859-1">
                <title>#{odin}</title>
                <p>Hello, world.
              HTML
            end

            it 'should be detected from a meta tag' do
              expect { checker.check }.to change { Message.count }.by(1)
              message = Message.last
              expect(message.payload['value']).to eq(odin)
            end
          end

          context 'with charset desclarations both in the header and in the content' do
            let :content_type do
              super() + '; charset=iso-8859-1'
            end

            let :body do
              <<~HTML.encode(Encoding::ISO_8859_1)
                <!DOCTYPE html>
                <meta charset="UTF-8">
                <title>#{odin}</title>
                <p>Hello, world.
              HTML
            end

            it 'should be detected as that of the header' do
              expect { checker.check }.to change { Message.count }.by(1)
              message = Message.last
              expect(message.payload['value']).to eq(odin)
            end
          end
        end

        context 'for an XML file' do
          let :content_type do
            'application/xml'
          end

          let :options do
            super().merge(
              'type' => 'xml',
              'extract' => {
                'value' => { 'xpath' => '/root/message', 'value' => 'string(.)' }
              }
            )
          end

          context 'with a charset in the header' do
            let :content_type do
              super() + '; charset=euc-jp'
            end

            let :body do
              <<~XML.encode(Encoding::EUC_JP)
                <?xml version="1.0"?>
                <root>
                  <message>#{thinking}</message>
                </root>
              XML
            end

            it 'should be detected from it' do
              expect { checker.check }.to change { Message.count }.by(1)
              message = Message.last
              expect(message.payload['value']).to eq(thinking)
            end
          end

          context 'with no charset in the header' do
            context 'but in XML declaration' do
              let :body do
                <<~XML.encode(Encoding::EUC_JP)
                  <?xml version="1.0" encoding="euc-jp"?>
                  <root>
                    <message>#{thinking}</message>
                  </root>
                XML
              end

              it 'should be detected' do
                expect { checker.check }.to change { Message.count }.by(1)
                message = Message.last
                expect(message.payload['value']).to eq(thinking)
              end
            end

            context 'but having a BOM' do
              let :body do
                <<~XML.encode(Encoding::UTF_16LE)
                  \u{feff}<?xml version="1.0"?>
                  <root>
                    <message>#{thinking}</message>
                  </root>
                XML
              end

              it 'should be detected' do
                expect { checker.check }.to change { Message.count }.by(1)
                message = Message.last
                expect(message.payload['value']).to eq(thinking)
              end
            end
          end
        end
      end

      context 'when force_encoding option is specified' do
        let :options do
          super().merge(
            'force_encoding' => 'EUC-JP'
          )
        end

        context 'for a JSON file' do
          let :content_type do
            'application/json'
          end

          let :body do
            {
              value: thinking
            }.to_json.encode(Encoding::EUC_JP)
          end

          let :options do
            super().merge(
              'type' => 'json',
              'extract' => {
                'value' => { 'path' => 'value' }
              }
            )
          end

          it 'should be forced' do
            expect { checker.check }.to change { Message.count }.by(1)
            message = Message.last
            expect(message.payload['value']).to eq(thinking)
          end
        end

        context 'for an HTML file' do
          let :content_type do
            'text/html'
          end

          context 'with charset specified in the header and the content' do
            let :content_type do
              super() + '; charset=UTF-8'
            end

            let :body do
              <<~HTML.encode(Encoding::EUC_JP)
                <!DOCTYPE html>
                <meta charset="UTF-8"/>
                <title>#{thinking}</title>
                <p>Hello, world.
              HTML
            end

            let :options do
              super().merge(
                'type' => 'html',
                'extract' => {
                  'value' => { 'css' => 'title', 'value' => 'string(.)' }
                }
              )
            end

            it 'should still be forced' do
              expect { checker.check }.to change { Message.count }.by(1)
              message = Message.last
              expect(message.payload['value']).to eq(thinking)
            end
          end
        end
      end
    end

    describe 'parsing' do
      it 'parses CSS' do
        @checker.check
        message = Message.last
        expect(message.payload['url']).to eq('http://imgs.xkcd.com/comics/evolving.png')
        expect(message.payload['title']).to eq('Evolving')
        expect(message.payload['hovertext']).to match(/^Biologists play reverse/)
      end

      it 'parses XPath' do
        @valid_options['extract'].each { |key, value|
          value.delete('css')
          value['xpath'] = "//*[@id='comic']//img"
        }
        @checker.options = @valid_options
        @checker.check
        message = Message.last
        expect(message.payload).to match(
          'url' => 'http://imgs.xkcd.com/comics/evolving.png',
          'title' => 'Evolving',
          'hovertext' => /^Biologists play reverse/
        )
      end

      it 'should exclude hidden keys' do
        @valid_options['extract']['hovertext']['hidden'] = true
        @checker.options = @valid_options
        @checker.check
        message = Message.last
        expect(message.payload).to match(
          'url' => 'http://imgs.xkcd.com/comics/evolving.png',
          'title' => 'Evolving'
        )
      end

      it 'should return an integer value if "value" evaluates to one' do
        rel_site = {
          'name' => 'XKCD',
          'expected_update_period_in_days' => 2,
          'type' => 'html',
          'url' => 'http://xkcd.com',
          'mode' => 'on_change',
          'extract' => {
            'num_links' => { 'css' => '#comicLinks', 'value' => 'count(./a)' }
          }
        }
        rel = Agents::WebsiteAgent.new(name: 'xkcd', options: rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        message = Message.last
        expect(message.payload['num_links']).to eq('9')
      end

      it 'should return an integer value if XPath evaluates to one' do
        rel_site = {
          'name' => 'XKCD',
          'expected_update_period_in_days' => 2,
          'type' => 'html',
          'url' => 'http://xkcd.com',
          'mode' => 'on_change',
          'extract' => {
            'num_links' => { 'xpath' => "count(//*[@id='comicLinks']/a)", 'value' => '.' }
          }
        }
        rel = Agents::WebsiteAgent.new(name: 'xkcd', options: rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        message = Message.last
        expect(message.payload['num_links']).to eq(9)
      end


      it 'should return everything concatenated if XPath returns many nodes' do
        rel_site = {
          'name' => 'XKCD',
          'expected_update_period_in_days' => 2,
          'type' => 'html',
          'url' => 'http://xkcd.com',
          'mode' => 'on_change',
          'extract' => {
            'slogan' => { 'css' => '#slogan', 'value' => './/text()' }
          }
        }
        rel = Agents::WebsiteAgent.new(name: 'xkcd', options: rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        message = Message.last
        expect(message.payload['slogan']).to eq('A webcomic of romance, sarcasm, math, &amp; language.')
      end

      it 'should return a string value returned by XPath' do
        rel_site = {
          'name' => 'XKCD',
          'expected_update_period_in_days' => 2,
          'type' => 'html',
          'url' => 'http://xkcd.com',
          'mode' => 'on_change',
          'extract' => {
            'slogan' => { 'css' => '#slogan', 'value' => 'string(.)' }
          }
        }
        rel = Agents::WebsiteAgent.new(name: 'xkcd', options: rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        message = Message.last
        expect(message.payload['slogan']).to eq('A webcomic of romance, sarcasm, math, & language.')
      end

      it 'should interpolate _response_' do
        @valid_options['url'] = 'http://xkcd.com/index'
        @valid_options['extract']['response_info'] =
          @valid_options['extract']['url'].merge(
            'value' => '{{ "The reponse from " | append:_response_.url | append:" was " | append:_response_.status | append:" " | append:_response_.headers.X-Status-Message | append:"." | to_xpath }}'
          )
        @valid_options['extract']['original_url'] =
          @valid_options['extract']['url'].merge(
            'value' => '{{ _url_ | to_xpath }}'
          )
        @checker.options = @valid_options
        @checker.check
        message = Message.last
        expect(message.payload['response_info']).to eq('The reponse from http://xkcd.com/ was 200 OK.')
        expect(message.payload['original_url']).to eq('http://xkcd.com/index')
      end

      it 'should format and merge values in template after extraction' do
        @valid_options['extract']['hovertext']['hidden'] = true
        @valid_options['template'] = {
          'title' => '{{title | upcase}}',
          'summary' => '{{title}}: {{hovertext | truncate: 20}}'
        }
        @checker.options = @valid_options
        @checker.check

        expect(@checker.message_keys).to contain_exactly('url', 'title', 'summary')
        expect(@checker.message_description.scan(/"(\w+)": "\.\.\."/).flatten).to contain_exactly('url', 'title', 'summary')

        message = Message.last
        expect(message.payload).to eq({
                                        'title' => 'EVOLVING',
                                        'url' => 'http://imgs.xkcd.com/comics/evolving.png',
                                        'summary' => 'Evolving: Biologists play r...'
                                      })
      end

      describe 'XML' do
        before do
          stub_request(:any, /github_commits/).to_return(
            body: File.read(Rails.root.join('spec/data_fixtures/github_commits.atom')),
            status: 200
          )

          @checker = Agents::WebsiteAgent.new(name: 'github', options: {
                                                'name' => 'GitHub',
                                                'expected_update_period_in_days' => '2',
                                                'type' => 'xml',
                                                'url' => 'http://example.com/github_commits.atom',
                                                'mode' => 'on_change',
                                                'extract' => {
                                                  'title' => { 'xpath' => '/feed/entry', 'value' => 'normalize-space(./title)' },
                                                  'url' => { 'xpath' => '/feed/entry', 'value' => './link[1]/@href' },
                                                  'thumbnail' => { 'xpath' => '/feed/entry', 'value' => './thumbnail/@url' },
                                                  'page_title': { 'xpath': '/feed/title', 'value': 'string(.)', 'repeat' => true }
                                                }
                                              }, keep_messages_for: 2.days)
          @checker.user = users(:bob)
          @checker.save!
        end

        it 'works with XPath' do
          expect {
            @checker.check
          }.to change { Message.count }.by(20)
          messages = Message.last(20)
          expect(messages.size).to eq(20)
          expect(messages.map { |message| message.payload['page_title'] }.uniq).to eq(['Recent Commits to rails:master'])
          message = messages.last
          expect(message.payload['title']).to eq('Merge pull request #36150 from rails/error-any-delegation')
          expect(message.payload['url']).to eq('https://github.com/rails/rails/commit/0c152f2eb419306578115da2c9fa10af575bede7')
          expect(message.payload['thumbnail']).to eq('https://avatars2.githubusercontent.com/u/3124?s=30&v=4')
        end

        it 'works with XPath with namespaces unstripped' do
          @checker.options['use_namespaces'] = 'true'
          @checker.save!
          expect {
            @checker.check
          }.to change { Message.count }.by(0)

          @checker.options['extract'] = {
            'title' => { 'xpath' => '/xmlns:feed/xmlns:entry', 'value' => 'normalize-space(./xmlns:title)' },
            'url' => { 'xpath' => '/xmlns:feed/xmlns:entry', 'value' => './xmlns:link[1]/@href' },
            'thumbnail' => { 'xpath' => '/xmlns:feed/xmlns:entry', 'value' => './media:thumbnail/@url' }
          }
          @checker.save!
          expect {
            @checker.check
          }.to change { Message.count }.by(20)
          message = Message.last
          expect(message.payload['title']).to eq('Merge pull request #36150 from rails/error-any-delegation')
          expect(message.payload['url']).to eq('https://github.com/rails/rails/commit/0c152f2eb419306578115da2c9fa10af575bede7')
          expect(message.payload['thumbnail']).to eq('https://avatars2.githubusercontent.com/u/3124?s=30&v=4')
        end

        it 'works with CSS selectors' do
          @checker.options['extract'] = {
            'title' => { 'css' => 'feed > entry', 'value' => 'normalize-space(./title)' },
            'url' => { 'css' => 'feed > entry', 'value' => './link[1]/@href' },
            'thumbnail' => { 'css' => 'feed > entry', 'value' => './thumbnail/@url' }
          }
          @checker.save!
          expect {
            @checker.check
          }.to change { Message.count }.by(20)
          message = Message.last
          expect(message.payload['title']).to be_empty
          expect(message.payload['thumbnail']).to be_empty

          @checker.options['extract'] = {
            'title' => { 'css' => 'feed > entry', 'value' => 'normalize-space(./xmlns:title)' },
            'url' => { 'css' => 'feed > entry', 'value' => './xmlns:link[1]/@href' },
            'thumbnail' => { 'css' => 'feed > entry', 'value' => './media:thumbnail/@url' }
          }
          @checker.save!
          expect {
            @checker.check
          }.to change { Message.count }.by(20)
          message = Message.last
          expect(message.payload['title']).to eq('Merge pull request #36150 from rails/error-any-delegation')
          expect(message.payload['url']).to eq('https://github.com/rails/rails/commit/0c152f2eb419306578115da2c9fa10af575bede7')
          expect(message.payload['thumbnail']).to eq('https://avatars2.githubusercontent.com/u/3124?s=30&v=4')
        end

        it 'works with CSS selectors with namespaces stripped' do
          @checker.options['extract'] = {
            'title' => { 'css' => 'feed > entry', 'value' => 'normalize-space(./title)' },
            'url' => { 'css' => 'feed > entry', 'value' => './link[1]/@href' },
            'thumbnail' => { 'css' => 'feed > entry', 'value' => './thumbnail/@url' }
          }
          @checker.options['use_namespaces'] = 'false'
          @checker.save!
          expect {
            @checker.check
          }.to change { Message.count }.by(20)
          message = Message.last
          expect(message.payload['title']).to eq('Merge pull request #36150 from rails/error-any-delegation')
          expect(message.payload['url']).to eq('https://github.com/rails/rails/commit/0c152f2eb419306578115da2c9fa10af575bede7')
          expect(message.payload['thumbnail']).to eq('https://avatars2.githubusercontent.com/u/3124?s=30&v=4')
        end
      end

      describe 'XML with cdata' do
        before do
          stub_request(:any, /cdata_rss/).to_return(
            body: File.read(Rails.root.join('spec/data_fixtures/cdata_rss.atom')),
            status: 200
          )

          @checker = Agents::WebsiteAgent.new(name: 'cdata', options: {
                                                'name' => 'CDATA',
                                                'expected_update_period_in_days' => '2',
                                                'type' => 'xml',
                                                'url' => 'http://example.com/cdata_rss.atom',
                                                'mode' => 'on_change',
                                                'extract' => {
                                                  'author' => { 'xpath' => '/feed/entry/author/name', 'value' => 'string(.)' },
                                                  'title' => { 'xpath' => '/feed/entry/title', 'value' => 'string(.)' },
                                                  'content' => { 'xpath' => '/feed/entry/content', 'value' => 'string(.)' }
                                                }
                                              }, keep_messages_for: 2.days)
          @checker.user = users(:bob)
          @checker.save!
        end

        it 'works with XPath' do
          expect {
            @checker.check
          }.to change { Message.count }.by(10)
          message = Message.last
          expect(message.payload['author']).to eq('bill98')
          expect(message.payload['title']).to eq('Help: Rainmeter Skins • Test if Today is Between 2 Dates')
          expect(message.payload['content']).to start_with('Can I ')
        end
      end

      describe 'JSON' do
        it 'works with paths' do
          json = {
            'response' => {
              'version' => 2,
              'title' => 'hello!'
            }
          }
          stub_request(:any, /json-site/).to_return(body: json.to_json, status: 200)
          site = {
            'name' => 'Some JSON Response',
            'expected_update_period_in_days' => '2',
            'type' => 'json',
            'url' => 'http://json-site.com',
            'mode' => 'on_change',
            'extract' => {
              'version' => { 'path' => 'response.version' },
              'title' => { 'path' => 'response.title' }
            }
          }
          checker = Agents::WebsiteAgent.new(name: 'Weather Site', options: site)
          checker.user = users(:bob)
          checker.save!

          expect(checker.message_keys).to contain_exactly('version', 'title')
          expect(checker.message_description.scan(/"(\w+)": "\.\.\."/).flatten).to contain_exactly('version', 'title')

          checker.check
          message = Message.last
          expect(message.payload['version']).to eq(2)
          expect(message.payload['title']).to eq('hello!')
        end

        it 'can handle arrays' do
          json = {
            'response' => {
              'status' => 'ok',
              'data' => [
                { 'title' => 'first', 'version' => 2 },
                { 'title' => 'second', 'version' => 2.5 }
              ]
            }
          }
          stub_request(:any, /json-site/).to_return(body: json.to_json, status: 200)
          site = {
            'name' => 'Some JSON Response',
            'expected_update_period_in_days' => '2',
            'type' => 'json',
            'url' => 'http://json-site.com',
            'mode' => 'on_change',
            'extract' => {
              'title' => { 'path' => 'response.data[*].title' },
              'version' => { 'path' => 'response.data[*].version' },
              'status' => { 'path' => 'response.status', 'repeat' => true }
            }
          }
          checker = Agents::WebsiteAgent.new(name: 'Weather Site', options: site)
          checker.user = users(:bob)
          checker.save!

          expect {
            checker.check
          }.to change { Message.count }.by(2)

          (message2, message1) = Message.last(2)
          expect(message1.payload['status']).to eq('ok')
          expect(message1.payload['version']).to eq(2.5)
          expect(message1.payload['title']).to eq('second')

          expect(message2.payload['status']).to eq('ok')
          expect(message2.payload['version']).to eq(2)
          expect(message2.payload['title']).to eq('first')
        end

        it 'stores the whole object if :extract is not specified' do
          json = {
            'response' => {
              'version' => 2,
              'title' => 'hello!'
            }
          }
          stub_request(:any, /json-site/).to_return(body: json.to_json, status: 200)
          site = {
            'name' => 'Some JSON Response',
            'expected_update_period_in_days' => '2',
            'type' => 'json',
            'url' => 'http://json-site.com',
            'mode' => 'on_change'
          }
          checker = Agents::WebsiteAgent.new(name: 'Weather Site', options: site)
          checker.user = users(:bob)
          checker.save!

          expect(checker.message_keys).to be_nil
          expect(checker.message_description).to match(/Messages will be the raw JSON returned by the URL/)
          checker.check
          message = Message.last
          expect(message.payload['response']['version']).to eq(2)
          expect(message.payload['response']['title']).to eq('hello!')
        end
      end

      describe 'text parsing' do
        before do
          stub_request(:any, /text-site/).to_return(body: <<~EOF, status: 200)
            VERSION 1
            water: wet
            fire: hot
          EOF
          site = {
            'name' => 'Some Text Response',
            'expected_update_period_in_days' => '2',
            'type' => 'text',
            'url' => 'http://text-site.com',
            'mode' => 'on_change',
            'extract' => {
              'version' => { 'regexp' => '^VERSION (.+)$', index: 1, repeat: true },
              'word' => { 'regexp' => '^(.+?): (.+)$', index: 1 },
              'property' => { 'regexp' => '^(.+?): (.+)$', index: '2' }
            }
          }
          @checker = Agents::WebsiteAgent.new(name: 'Text Site', options: site)
          @checker.user = users(:bob)
          @checker.save!
        end

        it 'works with regexp with named capture' do
          @checker.options = @checker.options.deep_merge('extract' => {
                                                           'word' => { 'regexp' => '^(?<word>.+?): (?<property>.+)$', index: 'word' },
                                                           'property' => { 'regexp' => '^(?<word>.+?): (?<property>.+)$', index: 'property' }
                                                         })

          expect {
            @checker.check
          }.to change { Message.count }.by(2)

          message1, message2 = Message.last(2)
          expect(message1.payload['version']).to eq('1')
          expect(message1.payload['word']).to eq('water')
          expect(message1.payload['property']).to eq('wet')
          expect(message2.payload['version']).to eq('1')
          expect(message2.payload['word']).to eq('fire')
          expect(message2.payload['property']).to eq('hot')
        end

        it 'works with regexp' do
          expect {
            @checker.check
          }.to change { Message.count }.by(2)

          message1, message2 = Message.last(2)
          expect(message1.payload['version']).to eq('1')
          expect(message1.payload['word']).to eq('water')
          expect(message1.payload['property']).to eq('wet')
          expect(message2.payload['version']).to eq('1')
          expect(message2.payload['word']).to eq('fire')
          expect(message2.payload['property']).to eq('hot')
        end
      end
    end

    describe '#receive' do
      describe 'with a url or url_from_message' do
        before do
          @message = Message.new
          @message.agent = agents(:bob_notifier_agent)
          @message.payload = {
            'url' => 'http://foo.com',
            'link' => 'Random'
          }
        end

        it 'should use url_from_message as the url to scrape' do
          stub = stub_request(:any, 'http://example.org/?url=http%3A%2F%2Ffoo.com')

          @checker.options = @valid_options.merge(
            'url_from_message' => 'http://example.org/?url={{url | uri_escape}}'
          )
          @checker.receive(@message)

          expect(stub).to have_been_requested
        end

        it "should use the Agent's `url` option if url_from_message is not set" do
          expect {
            @checker.options = @valid_options
            @checker.receive(@message)
          }.to change { Message.count }.by(1)
        end

        it 'should allow url_from_message to be an array of urls' do
          stub1 = stub_request(:any, 'http://example.org/?url=http%3A%2F%2Ffoo.com')
          stub2 = stub_request(:any, 'http://google.org/?url=http%3A%2F%2Ffoo.com')

          @checker.options = @valid_options.merge(
            'url_from_message' => ['http://example.org/?url={{url | uri_escape}}', 'http://google.org/?url={{url | uri_escape}}']
          )
          @checker.receive(@message)

          expect(stub1).to have_been_requested
          expect(stub2).to have_been_requested
        end

        it 'should interpolate values from incoming message payload' do
          stub_request(:any, /foo/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/xkcd.html')), status: 200)

          expect {
            @valid_options['url_from_message'] = '{{ url }}'
            @valid_options['extract'] = {
              'from' => {
                'xpath' => '*[1]',
                'value' => '{{url | to_xpath}}'
              },
              'to' => {
                'xpath' => '(//a[@href and text()={{link | to_xpath}}])[1]',
                'value' => '@href'
              }
            }
            @checker.options = @valid_options
            @checker.receive(@message)
          }.to change { Message.count }.by(1)

          expect(Message.last.payload).to eq({
                                               'from' => 'http://foo.com',
                                               'to' => 'http://dynamic.xkcd.com/random/comic/'
                                             })
        end

        it 'should use the options url if no url is in the message payload, and `url_from_message` is not provided' do
          @checker.options['mode'] = 'merge'
          @message.payload.delete('url')
          expect {
            @checker.receive(@message)
          }.to change { Message.count }.by(1)
          expect(Message.last.payload['title']).to eq('Evolving')
          expect(Message.last.payload['link']).to eq('Random')
        end

        it 'should interpolate values from incoming message payload and _response_' do
          @message.payload['title'] = 'XKCD'

          expect {
            @valid_options['extract'] = {
              'response_info' => @valid_options['extract']['url'].merge(
                'value' => '{% capture sentence %}The reponse from {{title}} was {{_response_.status}} {{_response_.headers.X-Status-Message}}.{% endcapture %}{{sentence | to_xpath}}'
              )
            }
            @checker.options = @valid_options
            @checker.receive(@message)
          }.to change { Message.count }.by(1)

          expect(Message.last.payload['response_info']).to eq('The reponse from XKCD was 200 OK.')
        end

        it 'should support merging of messages' do
          expect {
            @checker.options = @valid_options
            @checker.options[:mode] = 'merge'
            @checker.receive(@message)
          }.to change { Message.count }.by(1)
          last_payload = Message.last.payload
          expect(last_payload['link']).to eq('Random')
        end

        it 'returns an array of found nodes when the array extract_option is true' do
          stub_request(:any, /foo/).to_return(body: File.read(Rails.root.join('spec/data_fixtures/xkcd.html')), status: 200)

          @checker.options['extract']['nav_links'] = { 'css' => '#topLeft li', 'value' => 'normalize-space(.)', 'array' => 'true' }
          expect {
            @checker.receive(@message)
          }.to change { Message.count }.by(1)
          expect(Message.last.payload['nav_links']).to eq(['Archive', 'What If?', 'Blag', 'Store', 'About'])
        end
      end

      describe 'with a data_from_message' do
        describe 'with json data' do
          before do
            @message = Message.new
            @message.agent = agents(:bob_notifier_agent)
            @message.payload = {
              'something' => 'some value',
              'some_object' => {
                'some_data' => { hello: 'world', href: '/world' }.to_json
              },
              url: 'http://example.com/',
              'headers' => {
                'Content-Type' => 'application/json'
              },
              'status' => 200
            }
            @message.save!

            @checker.options = @valid_options.merge(
              'type' => 'json',
              'data_from_message' => '{{ some_object.some_data }}',
              'extract' => {
                'value' => { 'path' => 'hello' },
                'url' => { 'path' => 'href' }
              },
              'template' => {
                'value' => '{{ value }}',
                'url' => '{{ url | to_uri: _response_.url }}',
                'type' => '{{ _response_.headers.content_type }}',
                'status' => '{{ _response_.status | as_object }}'
              }
            )
          end

          it 'should extract from the message data in the incoming message payload' do
            expect {
              @checker.receive(@message)
            }.to change { Message.count }.by(1)
            expect(@checker.messages.last.payload).to eq({ 'value' => 'world', 'url' => 'http://example.com/world', 'type' => 'application/json', 'status' => 200 })
          end

          it 'should support merge mode' do
            @checker.options['mode'] = 'merge'

            expect {
              @checker.receive(@message)
            }.to change { Message.count }.by(1)
            expect(@checker.messages.last.payload).to eq(@message.payload.merge('value' => 'world', 'url' => 'http://example.com/world', 'type' => 'application/json', 'status' => 200))
          end

          it 'should convert headers and status in the message data properly' do
            @message.payload[:status] = '201'
            @message.payload[:headers] = [['Content-Type', 'application/rss+xml']]
            expect {
              @checker.receive(@message)
            }.to change { Message.count }.by(1)
            expect(@checker.messages.last.payload).to eq({ 'value' => 'world', 'url' => 'http://example.com/world', 'type' => 'application/rss+xml', 'status' => 201 })
          end

          it 'should ignore inconvertible headers and status in the message data' do
            @message.payload[:status] = 'ok'
            @message.payload[:headers] = ['Content-Type', 'Content-Length']
            expect {
              @checker.receive(@message)
            }.to change { Message.count }.by(1)
            expect(@checker.messages.last.payload).to eq({ 'value' => 'world', 'url' => 'http://example.com/world', 'type' => '', 'status' => nil })
          end

          it 'should output an error when nothing can be found at the path' do
            @checker.options = @checker.options.merge(
              'data_from_message' => '{{ some_object.mistake }}'
            )

            expect {
              @checker.receive(@message)
            }.to_not change { Message.count }

            expect(@checker.logs.last.message).to match(/No data was found in the message payload using the template {{ some_object\.mistake }}/)
          end

          it 'should output an error when the data cannot be parsed' do
            @message.update_attribute :payload, @message.payload.merge('some_object' => { 'some_data' => '{invalid json' })

            expect {
              @checker.receive(@message)
            }.to_not change { Message.count }

            expect(@checker.logs.last.message).to match(/Error when handling message data:/)
          end
        end

        describe 'with HTML data' do
          before do
            @message = Message.new
            @message.agent = agents(:bob_notifier_agent)
            @message.payload = {
              'url' => 'http://xkcd.com',
              'some_object' => {
                'some_data' => "<div><span class='title'>Title!</span><span class='body'>Body!</span></div>"
              }
            }
            @message.save!

            @checker.options = @valid_options.merge(
              'type' => 'html',
              'data_from_message' => '{{ some_object.some_data }}',
              'extract' => {
                'title' => { 'css' => '.title', 'value' => 'string(.)' },
                'body' => { 'css' => 'div span.body', 'value' => 'string(.)' }
              }
            )
          end

          it 'should extract from the message data in the incoming message payload' do
            expect {
              @checker.receive(@message)
            }.to change { Message.count }.by(1)
            expect(@checker.messages.last.payload).to eq({ 'title' => 'Title!', 'body' => 'Body!' })
          end
        end
      end
    end
  end

  describe 'checking with http basic auth' do
    before do
      @valid_options = {
        'name' => 'XKCD',
        'expected_update_period_in_days' => '2',
        'type' => 'html',
        'url' => 'http://www.example.com',
        'mode' => 'on_change',
        'extract' => {
          'url' => { 'css' => '#comic img', 'value' => '@src' },
          'title' => { 'css' => '#comic img', 'value' => '@alt' },
          'hovertext' => { 'css' => '#comic img', 'value' => '@title' }
        },
        'basic_auth' => 'user:pass'
      }
      @checker = Agents::WebsiteAgent.new(name: 'auth', options: @valid_options)
      @checker.user = users(:bob)
      @checker.save!

      stub_request(:any, 'www.example.com')
        .with(basic_auth: %w[user pass])
        .to_return(body: File.read(Rails.root.join('spec/data_fixtures/xkcd.html')), status: 200)
    end

    describe '#check' do
      it 'should check for changes' do
        expect { @checker.check }.to change { Message.count }.by(1)
        expect { @checker.check }.not_to change { Message.count }
      end
    end
  end

  describe 'checking with headers' do
    before do
      stub_request(:any, /example/)
        .with(headers: { 'foo' => 'bar' })
        .to_return(body: File.read(Rails.root.join('spec/data_fixtures/xkcd.html')), status: 200)
      @valid_options = {
        'name' => 'XKCD',
        'expected_update_period_in_days' => '2',
        'type' => 'html',
        'url' => 'http://www.example.com',
        'mode' => 'on_change',
        'headers' => { 'foo' => 'bar' },
        'extract' => {
          'url' => { 'css' => '#comic img', 'value' => '@src' }
        }
      }
      @checker = Agents::WebsiteAgent.new(name: 'ua', options: @valid_options)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe '#check' do
      it 'should check for changes' do
        expect { @checker.check }.to change { Message.count }.by(1)
      end
    end
  end

  describe 'checking urls' do
    before do
      stub_request(:any, /example/)
        .to_return(body: File.read(Rails.root.join('spec/data_fixtures/urlTest.html')), status: 200)
      @valid_options = {
        'name' => 'Url Test',
        'expected_update_period_in_days' => '2',
        'type' => 'html',
        'url' => 'http://www.example.com',
        'mode' => 'all',
        'extract' => {
          'url' => { 'css' => 'a', 'value' => '@href' }
        },
        'template' => {
          'url' => '{{ url | to_uri }}'
        }
      }
      @checker = Agents::WebsiteAgent.new(name: 'ua', options: @valid_options)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe '#check' do
      before do
        expect { @checker.check }.to change { Message.count }.by(8)
        @messages = Message.last(8)
      end

      it 'should check hostname' do
        message = @messages[0]
        expect(message.payload['url']).to eq('http://google.com')
      end

      it 'should check unescaped query' do
        message = @messages[1]
        expect(message.payload['url']).to eq('https://www.google.ca/search?q=some%20query')
      end

      it 'should check properly escaped query' do
        message = @messages[2]
        expect(message.payload['url']).to eq('https://www.google.ca/search?q=some%20query')
      end

      it 'should check unescaped unicode url' do
        message = @messages[3]
        expect(message.payload['url']).to eq('http://ko.wikipedia.org/wiki/%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8')
      end

      it 'should check unescaped unicode query' do
        message = @messages[4]
        expect(message.payload['url']).to eq('https://www.google.ca/search?q=%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8')
      end

      it 'should check properly escaped unicode url' do
        message = @messages[5]
        expect(message.payload['url']).to eq('http://ko.wikipedia.org/wiki/%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8')
      end

      it 'should check properly escaped unicode query' do
        message = @messages[6]
        expect(message.payload['url']).to eq('https://www.google.ca/search?q=%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8')
      end

      it 'should check url with unescaped brackets in the path component' do
        message = @messages[7]
        expect(message.payload['url']).to eq('http://[::1]/path%5B%5D?query[]=foo')
      end
    end
  end
end
