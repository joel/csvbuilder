# frozen_string_literal: true

RSpec.describe "Export" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "First Name"
      column :last_name, header: "Last Name"

      class << self
        def name
          "BasicRowModel"
        end

        def format_cell(cell, _column_name, _context)
          "- #{cell} -"
        end
      end
    end
  end

  let(:export_model) do
    Class.new(row_model) do
      include Csvbuilder::Export

      column :full_name, header: "Full Name"
      column :email, header: "Email"

      def email
        "#{first_name}.#{last_name}@example.co.uk".downcase
      end

      class << self
        def name
          "BasicExportModel"
        end
      end
    end
  end

  context "with user" do
    before do
      User.create(first_name: "John", last_name: "Doe", full_name: "John Doe")
    end

    describe "export" do
      subject(:exporter) { Csvbuilder::Export::File.new(export_model, context) }

      it "has the right headers" do
        expect(exporter.headers).to eq(["First Name", "Last Name", "Full Name", "Email"])
      end

      it "exports users data as CSV" do
        exporter.generate do |csv|
          User.all.each do |user|
            row_model = csv.append_model(user, another_context: true)

            # There is only one iteration here.

            expect(row_model.attributes).to eql(
              {
                first_name: "John",
                last_name: "Doe",
                full_name: "John Doe",
                email: "john.doe@example.co.uk"
              }
            )

            expect(row_model.original_attributes).to eql(
              {
                email: "- john.doe@example.co.uk -",
                first_name: "- John -",
                full_name: "- John Doe -",
                last_name: "- Doe -"
              }
            )
            expect(row_model.formatted_attributes).to eql(row_model.original_attributes)
            expect(row_model.source_attributes).to    eql(row_model.attributes)

            expect(row_model.attribute_objects.values.map(&:class)).to eql [Csvbuilder::Export::Attribute] * 4

            expect(row_model.attribute_objects[:first_name].value).to eql "- John -"
            expect(row_model.attribute_objects[:first_name].formatted_value).to eql "- John -"
            expect(row_model.attribute_objects[:first_name].source_value).to eql "John"
          end
        end

        expect(exporter.to_s).to eq("First Name,Last Name,Full Name,Email\n- John -,- Doe -,- John Doe -,- john.doe@example.co.uk -\n")
      end
    end
  end
end
