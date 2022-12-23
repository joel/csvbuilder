# frozen_string_literal: true

module Test
  class RowErrors
    attr_reader :headers, :errors

    def initialize
      @errors = []
    end

    def append_errors(row_model)
      @headers ||= begin
        errors << row_model.class.headers
        row_model.class.headers
      end

      row_in_error = []
      row_model.source_attributes.map do |key, value|
        row_in_error << if row_model.errors.messages[key].present?
                          "Initial Value: [#{value}] - Errors: #{row_model.errors.messages[key].join(", ")}"
                        else
                          value
                        end
      end
      errors << row_in_error
    end
  end
end

RSpec.describe "Import" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "First Name"
      column :last_name, header: "Last Name"

      class << self
        def name
          "BasicRowModel"
        end
      end
    end
  end
  let(:import_file) do
    Class.new(Csvbuilder::Import::File) do
      attr_reader :row_in_errors

      def initialize(*args)
        super
        @row_in_errors = Test::RowErrors.new
      end

      after_next do
        next true unless current_row_model
        next true if current_row_model.valid?

        row_in_errors.append_errors(current_row_model)
      end

      class << self
        def name
          "ImportFileWithErrorsHandling"
        end
      end
    end
  end

  let(:import_model) do
    Class.new(row_model) do
      include Csvbuilder::Import

      validates :first_name, presence: true, length: { minimum: 2 }

      def full_name
        "#{first_name} #{last_name}"
      end

      def user
        User.new(first_name: first_name, last_name: last_name, full_name: full_name)
      end

      def skip? # rubocop:disable Lint/UselessMethodDefinition
        super # Skip when importer is not valid
      end

      class << self
        def name
          "BasicImportModel"
        end
      end
    end
  end

  context "without user" do
    before { User.delete_all }

    describe "import" do
      context "with invalid data" do
        let(:csv_source) do
          [
            ["First name", "Last name"],
            %w[J Doe]
          ]
        end

        it "imports users" do
          importer = import_file.new(file.path, import_model, options)

          expect do
            expect { |row_model| importer.each(&row_model) }.not_to yield_control
          end.not_to change(User, :count)

          expect(importer.row_in_errors.errors).to eq(
            [
              ["First Name", "Last Name"],
              ["Initial Value: [J] - Errors: is too short (minimum is 2 characters)", "Doe"]
            ]
          )
        end
      end
    end
  end
end
