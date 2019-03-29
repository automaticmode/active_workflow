require 'rails_helper'
require 'capybara/rails'
require 'capybara-screenshot/rspec'
require 'capybara-select2'

CAPYBARA_TIMEOUT = ENV['CI'] == 'true' ? 60 : 5

Capybara.register_driver :headless_firefox do |app|
  browser_options = Selenium::WebDriver::Firefox::Options.new()
  browser_options.args << '--headless'
  Capybara::Selenium::Driver.new(app,
                                 browser: :firefox,
                                 options: browser_options)
end

Capybara.javascript_driver = :headless_firefox
Capybara.default_max_wait_time = CAPYBARA_TIMEOUT

Capybara::Screenshot.prune_strategy = { keep: 3 }

Capybara::Screenshot.register_driver(:headless_firefox) do |driver, path|
  driver.browser.save_screenshot(path)
end

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  config.include AlertConfirmer, type: :feature
  config.include FeatureHelpers, type: :feature

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
