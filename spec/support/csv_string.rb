# frozen_string_literal: true

module CsvString
  extend RSpec::SharedContext

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

  let(:context) { {} }
end
