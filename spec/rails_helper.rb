ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |file| require file }

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers

  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    tables = ActiveRecord::Base.connection.tables - %w[ schema_migrations ar_internal_metadata ]
    ActiveRecord::Base.connection.disable_referential_integrity do
      tables.each do |table|
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
      end
    end
  end

  config.before do
    tables = ActiveRecord::Base.connection.tables - %w[ schema_migrations ar_internal_metadata ]
    ActiveRecord::Base.connection.disable_referential_integrity do
      tables.each do |table|
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
      end
    end

    ApiRateLimiter.reset!
  end
end
