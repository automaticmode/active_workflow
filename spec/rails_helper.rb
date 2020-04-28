ENV['RAILS_ENV'] ||= 'test'

if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start 'rails'

  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'
require 'rr'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

# Mix in shoulda matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # rspec-rails 3 will no longer automatically infer an example group's spec type
  # from the file location. You can explicitly opt-in to this feature using this
  # snippet:
  config.infer_spec_type_from_file_location!

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
  config.global_fixtures = :all

  config.render_views

  config.example_status_persistence_file_path = './spec/examples.txt'

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include SpecHelpers
  config.include Delorean
  config.around(:each, :delayed_job) do |example|
    (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
    old_value = Delayed::Worker.delay_jobs
    Delayed::Worker.delay_jobs = true
    Delayed::Job.destroy_all

    example.run

    Delayed::Worker.delay_jobs = old_value
  end
end

require 'capybara_helper' if ENV['RSPEC_TASK'] != 'spec:nofeatures'
