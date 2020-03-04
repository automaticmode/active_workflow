source 'https://rubygems.org'

ruby '>=2.6.0'

# Ensure github repositories are fetched using HTTPS
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end if Gem::Version.new(Bundler::VERSION) < Gem::Version.new('2')

# Introduces a scope for gem loading based on a condition
def if_true(condition)
  if condition
    yield
  else
    # When not including the gems, we still want our Gemfile.lock
    # to include them, so we scope them to an unsupported platform.
    platform :ruby_18, &proc
  end
end

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
gem 'bootsnap', '>= 1.1.0', require: false
gem 'execjs', '~> 2.7.0'
gem 'mini_racer', '~> 0.2.8'
gem 'bootstrap', '~> 4.3.1'
gem 'bootstrap-kaminari-views', '~> 0.0.5'
gem 'daemons', '~> 1.2.6'
gem 'delayed_job', '~> 4.1.8'
gem 'delayed_job_active_record', '~> 4.1.4'
gem 'devise', '~> 4.7.1'
gem 'dotenv', '~> 2.5.0'
# TODO: update
gem 'faraday', '~> 0.9'
gem 'faraday_middleware', '~> 0.12.2'
gem 'feedjira', '~> 2.2'
gem 'font-awesome-sass', '~> 5.6.1'
gem 'httparty', '~> 0.16'
gem 'jquery-rails', '~> 4.3.5'
gem 'json', '~> 2.2.0'
gem 'jsonpath', '~> 1.0.1'
gem 'kaminari', '~> 1.1.1'
gem 'kramdown', '~> 2.1.0'
gem 'liquid', '~> 4.0.3'
gem 'loofah', '~> 2.3.1'
gem 'mini_magick', '~> 4.9.5'
gem 'nokogiri', '~> 1.10.8'
gem 'omniauth', '~> 1.9.0'
gem 'rack-timeout', '~> 0.5.1'
gem 'rails', '~> 5.2.3'
gem 'rails-html-sanitizer', '~> 1.0.4'
# TODO: Removing coffee-rails breaks deployment on heroku, investigate.
gem 'coffee-rails', '~> 4.2.2'
# TODO: update
gem 'rufus-scheduler', '~> 3.4.2', require: false
gem 'sass-rails', '~> 5.0'
# TODO: update
gem 'select2-rails', '~> 3.5.4'
gem 'source-sans-pro-rails', '~> 0.7.0'
gem 'spectrum-rails', '~> 1.8.0'
gem 'sprockets', '~> 3.7.2'
# TODO: update
gem 'typhoeus', '~> 0.6.3'
gem 'uglifier', '~> 4.1.18'
gem 'jquery-datatables', '~> 1.10.19'
gem 'grape', '~> 1.2.4'
gem 'grape-entity', '~> 0.7.1'
gem 'jwt', '~> 2.2.1'

group :development do
  gem 'foreman', '~> 0.86.0'
  gem 'bullet', '~> 6.0.1'
  gem 'sqlite3', '~> 1.4.1'
  gem 'better_errors', '~> 2.5.1'
  gem 'binding_of_caller', '~> 0.8.0'
  gem 'guard', '~> 2.16.1'
  gem 'guard-livereload', '~> 2.5.2'
  gem 'guard-rspec', '~> 4.7.3'
  gem 'letter_opener_web', '~> 1.3.4'
  gem 'overcommit', '~> 0.51.0'
  gem 'rack-livereload', '~> 0.3.17'
  gem 'rails_best_practices', '~> 1.19.4'
  gem 'reek', '~> 5.4.0'
  gem 'rubocop', '~> 0.76.0'
  gem 'web-console', '~> 3.7.0'

  if_true(ENV['SPRING']) do
    gem 'spring-commands-rspec', '~> 1.0.4'
    gem 'spring', '~> 2.0.2'
    gem 'spring-watcher-listen', '~> 2.0.1'
  end

  group :test do
    gem 'capybara', '~> 3.29.0'
    gem 'capybara-screenshot', '~> 1.0.23'
    gem 'capybara-select2', require: false
    gem 'codecov', '~> 0.1.16', require: false
    gem 'delorean', '~> 2.1.0'
    gem 'parallel_split_test', '~> 0.7.0'
    gem 'pry-byebug', '~> 3.7.0'
    gem 'pry-rails', '~> 0.3.9'
    gem 'rails-controller-testing', '~> 1.0.4'
    # TODO: update
    gem 'rr', '~> 1.1.2'
    gem 'rspec', '~> 3.9.0'
    gem 'rspec-rails', '~> 3.9.0'
    gem 'rspec-collection_matchers', '~> 1.2.0'
    gem 'rspec-html-matchers', '~> 0.9.2'
    gem 'rspec_junit_formatter', '~> 0.4.1'
    gem 'selenium-webdriver', '~> 3.142.6'
    gem 'shoulda-matchers', '~> 4.1.2'
    gem 'vcr', '~> 5.0.0'
    gem 'webmock', '~> 3.7.6'
  end
end

gem 'puma', '~> 4.3.3'

ENV['DATABASE_ADAPTER'] ||=
  if ENV['RAILS_ENV'] == 'production'
    'postgresql'
  else
    'sqlite3'
  end

if_true(ENV['DATABASE_ADAPTER'].strip == 'postgresql') do
  gem 'pg', '~> 1.1.4'
end
