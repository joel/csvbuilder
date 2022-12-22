# frozen_string_literal: true

RSpec.describe Csvbuilder do
  describe "import" do
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

  describe "export" do
    let(:context) { {} }

    context "with records" do
      subject(:exporter) { Csvbuilder::Export::File.new(BasicExportModel, context) }

      before do
        User.create(first_name: "John", last_name: "Doe", full_name: "John Doe")
      end

      after do
        User.delete_all
      end

      it "has the right headers" do
        expect(exporter.headers).to eq(["First Name", "Last Name", "Full Name"])
      end

      it "exports users data as CSV" do
        exporter.generate do |csv|
          User.all.each do |user|
            csv.append_model(user, another_context: true)
          end
        end

        expect(exporter.to_s).to eq("First Name,Last Name,Full Name\nJohn,Doe,John Doe\n")
      end
    end
  end

  context "with dynamic columns" do
    before do
      User.create(first_name: "John", last_name: "Doe", full_name: "John Doe")
      %w[Ruby Python Javascript].each do |skill_name|
        Skill.create(name: skill_name)
      end
    end

    after do
      User.delete_all
      Skill.delete_all
    end

    describe "import" do
      let(:csv_source) do
        [
          ["First name", "Last name", "Ruby", "Python", "Javascript"],
          %w[John Doe 1 0 1]
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
        Csvbuilder::Import::File.new(file.path, DynamicColumnsImportModel, options).each do |row_model|
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

    describe "export" do
      let(:context) { { skills: Skill.pluck(:name) } }
      let(:sub_context) { {} }

      before do
        User.where(full_name: "John Doe").take.skills << Skill.where(name: "Ruby")
      end

      it "export users with their skills" do
        exporter = Csvbuilder::Export::File.new(DynamicColumnsExportModel, context)
        expect(exporter.headers).to eq(%w[Name Surname Ruby Python Javascript])

        exporter.generate do |csv|
          User.all.each do |user|
            csv.append_model(user, sub_context)
          end
        end

        expect(exporter.to_s).to eq("Name,Surname,Ruby,Python,Javascript\nJohn,Doe,1,0,0\n")
      end
    end
  end
end
