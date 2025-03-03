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

      validates :first_name, presence: true, length: { minimum: 2 }
      validates :last_name, presence: true, length: { minimum: 2 }

      # Skip if the row is not valid,
      # the user is not found or the user is not valid
      def skip?
        super || user.nil?
      end

      class << self
        def name
          "DynamicColumnsImportModel"
        end

        def with_dynmic_columns(collection_name:, collection:)
          new_class = Class.new(self) do
            instance_variable_set(:"@#{collection_name}_columns", {})

            collection.each.with_index do |entry, index|
              column_name = :"#{collection_name}_#{index}"
              define_dynamic_column(entry, column_name: column_name)
              instance_variable_get(:"@#{collection_name}_columns")[column_name] = columns[column_name]
            end

            class << self
              attr_reader :skill_columns
              # attr_reader :"#{collection_name}_columns"
            end

            define_method(:"#{collection_name}_columns") do
              self.class.send(:"#{collection_name}_columns")
            end
          end

          Object.send(:remove_const, "DynamicColumnsImportModel") if Object.const_defined?(:DynamicColumnsImportModel)
          Object.const_set(:DynamicColumnsImportModel, new_class)

          new_class
        end

        def define_dynamic_column(entry, column_name:)
          column(column_name, header: entry.name, required: false)
          validates(column_name, inclusion: %w[0 1], allow_blank: true)
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
        let(:importer_with_dynamic_columns) { import_model.with_dynmic_columns(collection_name: :skill, collection: Skill.all) }

        describe "import" do
          let(:csv_source) do
            [
              %w[Name Surname Ruby Python Javascript],
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
              row_model.skill_columns.each do |column_name, skill_data|
                row_cell_value = row_model.attribute_objects[column_name].value # Get the value of the cell

                skill = Skill.find_or_create_by(name: skill_data[:header])

                row_model.user.skills << skill if row_cell_value == "1"
              end

              expect(row_model.user.skills).to be_truthy
              expect(row_model.user.skills.count).to eq(2)
              expect(row_model.user.skills.map(&:name)).to match_array(%w[Ruby Javascript])
            end
          end
        end

        context "with invalid data" do
          let(:csv_source) do
            [
              %w[Name Surname Ruby Python Javascript],
              %w[John Doe 1 0 2]
            ]
          end

          before do
            allow_any_instance_of(importer_with_dynamic_columns).to receive(:skip?).and_return(false)
          end

          it "does not import users" do
            importer = Csvbuilder::Import::File.new(file.path, importer_with_dynamic_columns, options)

            enum = importer.each
            row_model = enum.next

            expect(row_model).not_to be_valid

            expect(row_model.errors.full_messages).to eq(["Skill 2 is not included in the list"])
          end
        end

        context "with invalid headers" do
          let(:csv_source) do
            [
              ["Name", "Surname", "Ruby", "Python", "Visual Basic"],
              %w[John Doe 1 0 2]
            ]
          end

          let(:importer) { Csvbuilder::Import::File.new(file.path, importer_with_dynamic_columns, options) }

          it "does not import users" do
            expect { importer.each.next }.to raise_error(StopIteration)

            expect(importer.errors.full_messages).to eq(
              [
                "Headers mismatch. Given headers (Name, Surname, Ruby, Python, Visual Basic). Expected headers (Name, Surname, Ruby, Python, Javascript). Unrecognized headers (Visual Basic)."
              ]
            )
          end
        end
      end
    end
  end
end
