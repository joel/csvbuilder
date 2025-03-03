# frozen_string_literal: true

ActiveRecord::Schema.define do
  self.verbose = ENV.fetch("DEBUG", nil)

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

  create_table :areas, force: true do |t|
    t.string :name
  end

  create_table :tags, force: true do |t|
    t.string :name
    t.references(:area)
  end

  create_table :taggings, force: true do |t|
    t.references(:tag)
    t.references(:source, polymorphic: true)
  end
end
