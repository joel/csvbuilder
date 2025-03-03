# frozen_string_literal: true

class User < ActiveRecord::Base
  self.table_name = :users

  validates :full_name, presence: true

  has_and_belongs_to_many :skills, join_table: :skills_users
  has_many :taggings, as: :source
end

class Skill < ActiveRecord::Base
  self.table_name = :skills

  validates :name, presence: true
end

class Area < ActiveRecord::Base
  has_many :tags
end

class Tag < ActiveRecord::Base
  belongs_to :area
end

class Tagging < ActiveRecord::Base
  belongs_to :tag
  belongs_to :source, polymorphic: true
end
