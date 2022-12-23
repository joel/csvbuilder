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

  let(:export_model) do
    Class.new(row_model) do
      include Csvbuilder::Export

      include Csvbuilder::Import

      def full_name
        "#{first_name} #{last_name}"
      end

      def user
        User.new(first_name: first_name, last_name: last_name, full_name: full_name)
      end
    end
  end

  context "without user" do
    before { User.delete_all }

    describe "import" do
      let(:csv_source) do
        [
          ["First name", "Last name"],
          %w[John Doe]
        ]
      end

      it "imports users" do
        Csvbuilder::Import::File.new(file.path, BasicImportModel, options).each do |row_model|
          user = row_model.user
          expect(user).to be_valid
          expect do
            user.save
          end.to change(User, :count).by(+1)

          expect(user.full_name).to eq("John Doe")
        end
      end
    end
  end
end
