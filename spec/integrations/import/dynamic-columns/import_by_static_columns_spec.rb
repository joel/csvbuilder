# frozen_string_literal: true

RSpec.describe "Import With Metaprogramming Instead Of Dynamic Columns" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "Name"
      column :last_name, header: "Surname"

      class << self
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
        { name: skill_name, level: value }
      end

      class << self
        def name
          "DynamicColumnsImportModel"
        end

        def with_skills(skills)
          new_class = Class.new(self) do
            @skill_columns = []

            skills.each.with_index do |skill, index|
              column_name = :"skill_#{index}"
              define_skill_column(skill, name: column_name)
              @skill_columns << column_name
            end

            class << self
              attr_reader :skill_columns
            end

            def skill_columns
              self.class.skill_columns
            end

            def skills
              skill_columns
                .flat_map { public_send it }
                .reject(&:blank?)
            end
          end

          Object.const_set(name, new_class) unless Object.const_defined?(name)

          new_class
        end

        def define_skill_column(skill, name:)
          column(name, header: skill.name, required: false)
          validates(name, inclusion: Skill.pluck(&:name), allow_blank: true)
        end
      end
    end
  end

  context "with user" do
    before do
      User.create(first_name: "John", last_name: "Doe", full_name: "John Doe")
    end

    context "with skills" do
      before do
        %w[Ruby Python Javascript].each do |skill_name|
          Skill.create(name: skill_name)
        end
      end

      context "with dynamic columns" do
        let(:importer_with_dynamic_columns) { import_model.with_skills(Skill.all) }

        describe "import" do
          let(:csv_source) do
            [
              ["First name", "Last name", "Ruby", "Python", "Javascript"],
              %w[John Doe 1 0 1]
            ]
          end

          it "masquerade the import_model class" do
            expect(import_model.name).to eq("DynamicColumnsImportModel")
            expect(importer_with_dynamic_columns.name).to eq("DynamicColumnsImportModel")
          end

          it "adds skills to column names" do
            expect(importer_with_dynamic_columns.column_names).to match_array(%i[first_name last_name skill_0 skill_1 skill_2])
          end

          it "adds skills to headers" do
            expect(importer_with_dynamic_columns.headers).to match_array(%w[Name Surname Ruby Python Javascript])
          end

          it "adds skills to users" do
            Csvbuilder::Import::File.new(file.path, importer_with_dynamic_columns, options).each do |row_model|
              row_model.skills.each do |skill_data|
                skill = Skill.find_or_create_by(name: skill_data[:name])
                row_model.user.skills << skill if skill_data[:level] == "1"
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
