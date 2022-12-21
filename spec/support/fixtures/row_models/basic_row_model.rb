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
