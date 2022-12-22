# frozen_string_literal: true

class BasicRowModel
  include Csvbuilder::Model

  column :first_name, header: "First Name"
  column :last_name, header: "Last Name"
end

#
# Import
#
class BasicImportModel < BasicRowModel
  include Csvbuilder::Import

  def full_name
    "#{first_name} #{last_name}"
  end

  def user
    User.new(first_name: first_name, last_name: last_name, full_name: full_name)
  end
end

#
# Export
#
class BasicExportModel < BasicRowModel
  include Csvbuilder::Export

  column :full_name, header: "Full Name"
end

# Dynamic columns

class DynamicColumnsRowModel
  include Csvbuilder::Model

  column :first_name
  column :last_name

  dynamic_column :skills
end

#
# Import
#
class DynamicColumnsImportModel < DynamicColumnsRowModel
  include Csvbuilder::Import

  def user
    User.find_by(full_name: "#{first_name} #{last_name}")
  end

  def skill(value, skill_name)
    { name: skill_name, level: value }
  end
end