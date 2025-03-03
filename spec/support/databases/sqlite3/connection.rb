# frozen_string_literal: true

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

RSpec.configure do |config|
  config.before(:suite) do
    # Load the schema
    load File.expand_path("../sqlite3/schema.rb", __dir__)

    # Load the data
    load File.expand_path("../../data.rb", __dir__)
  end
end
