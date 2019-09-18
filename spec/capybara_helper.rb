require 'rails_helper'
require 'capybara/rails'
require 'capybara-screenshot/rspec'
require 'capybara-select2'

CAPYBARA_TIMEOUT = ENV['CI'] == 'true' ? 60 : 5

Capybara.register_driver :chromium_headless do |app|
  browser_options = Selenium::WebDriver::Chrome::Options.new()
  browser_options.args << '--headless'
  browser_options.args << '--no-sandbox'
  browser_options.args << '--disable-dev-shm-usage'
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
end

Capybara.default_driver = :chromium_headless
Capybara.javascript_driver = :chromium_headless

Capybara.default_max_wait_time = CAPYBARA_TIMEOUT

Capybara::Screenshot.prune_strategy = { keep: 3 }

Capybara::Screenshot.register_driver(:chromium_headless) do |driver, path|
  driver.browser.save_screenshot(path)
end

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  config.include AlertConfirmer, type: :feature
  config.include FeatureHelpers, type: :feature

  config.before(:each, type: :feature) do
    Capybara.current_session.driver.browser.manage.window.resize_to(1024, 768)
  end

  config.before(:suite) do
    Warden.test_mode!
  end

  config.after(:each) do
    Warden.test_reset!
  end
end

VCR.configure do |config|
  config.ignore_localhost = true
end
