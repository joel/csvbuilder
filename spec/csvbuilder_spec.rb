# frozen_string_literal: true

RSpec.describe Csvbuilder do
  let(:csv_source) do
    [
      ["First name", "Last name"],
      %w[John Doe]
    ]
  end

  let(:csv_string) do
    CSV.generate do |csv|
      csv_source.each { |row| csv << row }
    end
  end

  let(:file) do
    file = Tempfile.new(["input_file", ".csv"])
    file.write(csv_string)
    file.rewind
    file
  end

  let(:options) { {} }

  it "import users" do
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
