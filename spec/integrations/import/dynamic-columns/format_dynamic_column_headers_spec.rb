# frozen_string_literal: true

RSpec.describe "Import With Dynamic Columns" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "Name"
      column :last_name, header: "Surname"

      dynamic_column :skills # , header: ->(name) { "SKILLS: #{name}" }

      class << self
        # Same as:
        # dynamic_column :skills, header: ->(name) { "SKILLS: #{name}" }
        def format_dynamic_column_header(header_model, column_name, _context)
          "#{column_name.upcase}: #{header_model}"
        end

        def name
          "DynamicColumnsRowModel"
        end
      end
    end
  end

  let(:import_model) do
    Class.new(row_model) do
      include Csvbuilder::Import

      def user
        User.find_by(full_name: "#{first_name} #{last_name}")
      end

      def skill(value, skill_name)
        name = skill_name.gsub("SKILLS: ", "") # Remove formatting

        Class.new(OpenStruct) do
          def has?
            has == "1"
          end
        end.new({ name: name, has: value })
      end

      class << self
        def name
          "DynamicColumnsImportModel"
        end
      end
    end
  end

  context "with user" do
    before do
      User.create(first_name: "John", last_name: "Doe", full_name: "John Doe")
    end

    after { User.delete_all }

    context "with skills" do
      before do
        %w[Ruby Python Javascript].each do |skill_name|
          Skill.create(name: skill_name)
        end
      end

      after { Skill.delete_all }

      context "with dynamic columns" do
        describe "import" do
          let(:csv_source) do
            [
              ["First name", "Last name", "Ruby", "Python", "Javascript"],
              %w[John Doe 1 0 1]
            ]
          end

          it "adds skills to users" do
            Csvbuilder::Import::File.new(file.path, import_model, options).each do |row_model|
              row_model.skills.each do |skill|
                row_model.user.skills << Skill.find_or_create_by(name: skill.name) if skill.has?
              end

              expect(row_model.user.skills).to be_truthy
              expect(row_model.user.skills.count).to eq(2)
              expect(row_model.user.skills.map(&:name)).to match_array(%w[Ruby Javascript])
            end
          end
        end
      end
    end
  end
end
