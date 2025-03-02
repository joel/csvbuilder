# frozen_string_literal: true

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

  let(:import_model) do
    Class.new(row_model) do
      include Csvbuilder::Import

      validates :first_name, presence: true, length: { minimum: 2 }
      validate :custom_last_name

      def full_name
        "#{first_name} #{last_name}"
      end

      def user
        User.new(first_name: first_name, last_name: last_name, full_name: full_name)
      end

      def custom_last_name
        errors.add(:last_name, "must be Doe") unless last_name == "Doe"
      end

      class << self
        def name
          "BasicImportModel"
        end
      end
    end
  end

  context "without user" do
    let(:csv_source) do
      [
        ["First Name", "Last Name"],
        %w[John Doe]
      ]
    end
    let(:importer) { Csvbuilder::Import::File.new(file.path, import_model, options) }
    let(:row_enumerator) { importer.each }

    describe "#each" do
      context "when everything goes well" do
        it "imports users" do
          row_enumerator.each do |row_model|
            expect(row_model.headers).to eq(["First Name", "Last Name"])
            expect(row_model.source_headers).to eq(["First Name", "Last Name"])
            expect(row_model.source_row).to eq(%w[John Doe])

            expect(row_model.source_attributes.values).to eq(row_model.source_row)
            expect(row_model.formatted_attributes.values).to eq(row_model.original_attributes.values)

            user = row_model.user
            expect(user).to be_valid
            expect do
              user.save
            end.to change(User, :count).by(+1)

            expect(user.full_name).to eq("John Doe")
          end

          expect(User.count).to eq(1)
        end
      end

      context "when abort!" do
        before { importer.abort! }

        it "aborts import" do
          expect { row_enumerator.next }.to raise_error(StopIteration)
        end
      end
    end
  end
end
