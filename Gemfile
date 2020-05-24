source 'https://rubygems.org'

ruby '>=2.6.0'

# Optional libraries.  To conserve RAM, comment out any that you don't need,
# then run `bundle` and commit the updated Gemfile and Gemfile.lock.
# TODO: update
gem 'twilio-ruby', '~> 3.11.5'    # TwilioAgent
gem 'net-ftp-list', '~> 3.2.8'    # FtpsiteAgent
gem 'rturk', '~> 2.12.1'          # HumanTaskAgent
# Required by rturk, fixes Fixnum bug.
gem 'erector', git: 'https://github.com/erector/erector', ref: '59754211101b2c50a4c9daa8e64a64e6edc9e976'
# TODO: update
gem 'slack-notifier', '~> 1.0.0'  # SlackAgent

# EvernoteAgent
gem 'omniauth-evernote'
gem 'evernote_oauth'

# S3Agent
# TODO: update
gem 'aws-sdk-core', '~> 2.2.15'

# Optional Services.
gem 'omniauth-37signals' # BasecampAgent
gem 'omniauth-wunderlist'

gem 'ace-rails-ap', '~> 4.2'
gem 'bootsnap', '>= 1.4.6', require: false
gem 'execjs', '~> 2.7.0'
gem 'mini_racer', '~> 0.2.8'
gem 'bootstrap', '~> 4.4.1'
gem 'daemons', '~> 1.2.6'
gem 'delayed_job', '~> 4.1.8'
gem 'delayed_job_active_record', '~> 4.1.4'
gem 'devise', '~> 4.7.1'
gem 'dotenv', '~> 2.5.0'
# TODO: update
gem 'faraday', '~> 0.9'
gem 'faraday_middleware', '~> 0.12.2'
gem 'feedjira', '~> 2.2'
gem 'font-awesome-sass', '~> 5.12.0'
gem 'httparty', '~> 0.16'
gem 'jquery-rails', '~> 4.3.5'
gem 'json', '~> 2.3.0'
gem 'jsonpath', '~> 1.0.1'
gem 'kaminari', '~> 1.1.1'
gem 'kramdown', '~> 2.1.0'
gem 'liquid', '~> 4.0.3'
gem 'loofah', '~> 2.5.0'
gem 'mini_magick', '~> 4.9.5'
gem 'nokogiri', '~> 1.10.8'
gem 'omniauth', '~> 1.9.0'
gem 'rack-timeout', '~> 0.5.1'
gem 'rails', '~> 6.0.2'
gem 'rails-html-sanitizer', '~> 1.3.0'
# TODO: Removing coffee-rails breaks deployment on heroku, investigate.
gem 'coffee-rails', '~> 4.2.2'
# TODO: update
gem 'rufus-scheduler', '~> 3.4.2', require: false
gem 'sass-rails', '~> 5.0'
gem 'sassc', '~>2.3.0'
# TODO: update
gem 'select2-rails', '~> 3.5.4'
gem 'source-sans-pro-rails', '~> 0.7.0'
gem 'spectrum-rails', '~> 1.8.0'
gem 'sprockets', '~> 3.7.2'
# TODO: update
gem 'typhoeus', '~> 1.3.1'
gem 'uglifier', '~> 4.1.18'
gem 'jquery-datatables', '~> 1.10.19'
gem 'grape', '~> 1.3.2'
gem 'grape-entity', '~> 0.8.0'
gem 'jwt', '~> 2.2.1'

group :development do
  gem 'foreman', '~> 0.87.1'
  gem 'bullet', '~> 6.1.0'
  gem 'sqlite3', '~> 1.4.2'
  gem 'better_errors', '~> 2.7.0'
  gem 'binding_of_caller', '~> 0.8.0'
  gem 'guard', '~> 2.16.2'
  gem 'guard-livereload', '~> 2.5.2'
  gem 'guard-rspec', '~> 4.7.3'
  gem 'letter_opener_web', '~> 1.4.0'
  gem 'overcommit', '~> 0.53.0'
  gem 'rack-livereload', '~> 0.3.17'
  gem 'rails_best_practices', '~> 1.20.0'
  gem 'reek', '~> 6.0.0'
  gem 'rubocop', '~> 0.82.0'
  gem 'web-console', '~> 3.7.0'

  group :test do
    gem 'capybara', '~> 3.32.1'
    gem 'capybara-screenshot', '~> 1.0.24'
    gem 'capybara-select2', require: false
    gem 'codecov', '~> 0.1.16', require: false
    gem 'delorean', '~> 2.1.0'
    gem 'pry-byebug', '~> 3.9.0'
    gem 'pry-rails', '~> 0.3.9'
    gem 'rails-controller-testing', '~> 1.0.4'
    # TODO: update
    gem 'rr', '~> 1.1.2'
    gem 'rspec', '~> 3.9.0'
    gem 'rspec-rails', '~> 4.0.0'
    gem 'rspec-collection_matchers', '~> 1.2.0'
    gem 'rspec-html-matchers', '~> 0.9.2'
    gem 'rspec_junit_formatter', '~> 0.4.1'
    gem 'selenium-webdriver', '~> 3.142.7'
    gem 'shoulda-matchers', '~> 4.3.0'
    gem 'vcr', '~> 5.1.0'
    gem 'webmock', '~> 3.8.3'
  end
end

gem 'puma', '~> 4.3.5'

ENV['DATABASE_ADAPTER'] ||=
  if ENV['RAILS_ENV'] == 'production'
    'postgresql'
  else
    'sqlite3'
  end

gem 'pg', '~> 1.2.3'
