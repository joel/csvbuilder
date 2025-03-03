# frozen_string_literal: true

class User < ActiveRecord::Base
  self.table_name = :users

  validates :full_name, presence: true

  has_and_belongs_to_many :skills, join_table: :skills_users
end

class Skill < ActiveRecord::Base
  self.table_name = :skills

  validates :name, presence: true
end
