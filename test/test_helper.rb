ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# The test DB user lacks superuser, so Rails can't introspect pg_catalog for FK validation
ActiveRecord.verify_foreign_keys_for_fixtures = false

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    def sign_in_as(user)
      post session_path, params: { email_address: user.email_address, password: "password" }
    end
  end
end
