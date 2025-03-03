# frozen_string_literal: true

require "csvbuilder"
require "active_record"
# [Getting rid of logger breaks rails 7.0.8 on ruby 3.3.6 #1077](https://github.com/ruby-concurrency/concurrent-ruby/issues/1077)
# [Ensure the logger gem is loaded in Rails 7.0 #54264](https://github.com/rails/rails/pull/54264/files)
# require "logger"
require "tempfile"

# Load support files
Dir["./spec/support/**/*.rb"].each do |file|
  next if /databases|models|data/.match?(file) # "support/databases/#{database}/connection" load models and data

  puts("Loading #{file}")

  require file
end

# Load database support files
ENV["DATABASE"] ||= "sqlite3"
database = ENV.fetch("DATABASE", "sqlite3")

puts("Loading support/databases/#{database}/connection")

require "support/databases/#{database}/connection"

require "support/database_cleaner"

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include CsvString
end
