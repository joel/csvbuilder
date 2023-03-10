# frozen_string_literal: true

require "csvbuilder"
require "active_record"
# require "logger"
require "tempfile"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
# ActiveRecord::Base.logger = Logger.new($stdout)
# ActiveRecord::Migration.verbose = true

Dir["#{Dir.pwd}/spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include CsvString
end

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :first_name
    t.string :last_name
    t.string :full_name
  end
  create_table :skills_users, force: true do |t|
    t.references :skill
    t.references :user
  end
  create_table :skills, force: true do |t|
    t.string :name
  end
end

class User < ActiveRecord::Base
  self.table_name = :users

  validates :full_name, presence: true

  has_and_belongs_to_many :skills, join_table: :skills_users
end

class Skill < ActiveRecord::Base
  self.table_name = :skills

  validates :name, presence: true
end
