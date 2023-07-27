# frozen_string_literal: true

RSpec.describe "Validation Dynamic Headers Value Over Import" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "Name"
      column :last_name, header: "Surname"

      dynamic_column :skills

      def dynamic_column_header_scope
        Skill
      end

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

      context "with importer validations" do
        let(:importer) do
          Class.new(Csvbuilder::Import::File) do
            after_next do
              next if end_of_file?

              validate_dynamic_headers

              abort! if errors.any?
            end

            private

            def validate_dynamic_headers
              return unless defined?(Csvbuilder::Model::DynamicColumns)
              return unless headers?

              current_row_model.dynamic_column_source_headers.each do |dynamic_header|
                next if current_row_model.dynamic_column_header_scope.where(name: dynamic_header).exists?

                errors.add(:base, "Skill #{dynamic_header} does not exist")
              end
            end

            def headers?
              current_row_model && previous_row_model.nil?
            end
          end
        end

        describe "import" do
          let(:csv_source) do
            [
              ["First name", "Last name", "Ruby", "Python", "Javascript"],
              %w[John Doe 1 0 1]
            ]
          end

          before do
            Skill.where(name: "Javascript").take.destroy
          end

          it "does not add data if validation fail" do
            row_enumerator = importer.new(file.path, import_model, options).each

            expect do
              row_enumerator.next
            end.to raise_error(StopIteration)
          end
        end
      end
    end
  end
end
