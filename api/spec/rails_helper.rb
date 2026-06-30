ENV["RAILS_ENV"] ||= "test"

require "spec_helper"
require_relative "../config/environment"
require "rspec/rails"

abort("The Rails environment is running in production mode!") if Rails.env.production?

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = []
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include Module.new {
    def parsed_body
      JSON.parse(response.body)
    end

    def create_user(email: "ana@example.com", password: "senha-segura-123", name: "Ana")
      user = User.new(
        name: name,
        email: email,
        timezone: "America/Bahia",
        locale: "pt-BR",
        plan: "free",
        account_status: "active"
      )
      user.password = password
      user.save!
      user
    end

    def issue_cookie_for(user, source: "web", correlation_id: "cor_spec_12345")
      raw_token, = user.issue_session!(source: source, correlation_id: correlation_id)
      "_orb_session=#{raw_token}"
    end
  }
end
