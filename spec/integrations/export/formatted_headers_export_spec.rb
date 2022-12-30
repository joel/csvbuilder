# frozen_string_literal: true

RSpec.describe "Export" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "First Name"
      column :last_name

      class << self
        def name
          "BasicRowModel"
        end

        # Is not applied to the header if :header option is present
        def format_header(column_name, _context)
          "HEADER: #{column_name}"
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

    after { User.delete_all }

    describe "export" do
      subject(:exporter) { Csvbuilder::Export::File.new(export_model, context) }

      it "has the right headers" do
        expect(exporter.headers).to eq(["First Name", "HEADER: last_name", "Full Name", "Email"])
      end

      it "exports users data as CSV" do
        exporter.generate do |csv|
          User.all.each do |user|
            csv.append_model(user, another_context: true)
          end
        end

        expect(exporter.to_s).to eq("First Name,HEADER: last_name,Full Name,Email\nJohn,Doe,John Doe,john.doe@example.co.uk\n")
      end
    end
  end
end
