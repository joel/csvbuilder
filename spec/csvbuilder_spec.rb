# frozen_string_literal: true

RSpec.describe Csvbuilder do
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

  context "with user" do
    before do
      User.create(first_name: "John", last_name: "Doe", full_name: "John Doe")
    end

    after { User.delete_all }

    describe "export" do
      subject(:exporter) { Csvbuilder::Export::File.new(BasicExportModel, context) }

      let(:context) { {} }

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

    context "with skills" do
      before do
        %w[Ruby Python Javascript].each do |skill_name|
          Skill.create(name: skill_name)
        end
      end

      after { Skill.delete_all }

      context "with dynamic columns" do
        describe "import" do
          let(:row_model)    { DynamicColumnsRowModel }
          let(:import_model) { DynamicColumnsImportModel }
          let(:csv_source) do
            [
              ["First name", "Last name", "Ruby", "Python", "Javascript"],
              %w[John Doe 1 0 1]
            ]
          end

          context "with bare import model" do
            it "adds skills to users" do
              Csvbuilder::Import::File.new(file.path, import_model, options).each do |row_model|
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

          context "with overriden import model" do
            let(:row_model) do
              Class.new(DynamicColumnsRowModel) do
                class << self
                  # Safe to override. Method applied to each dynamic_column attribute
                  #
                  # @param cells [Array] Array of values
                  # @param column_name [Symbol] Dynamic column name
                  def format_dynamic_column_cells(cells, _column_name, _context)
                    cells.select(&:has?).map(&:name)
                  end
                end
              end
            end
            let(:import_model) do
              Class.new(row_model) do
                include Csvbuilder::Import
                class << self
                  def name
                    "DynamicColumnsImportModel"
                  end
                end

                def user
                  User.find_by(full_name: "#{first_name} #{last_name}")
                end

                def skill(value, skill_name)
                  Class.new(OpenStruct) do
                    def has?
                      has == "1"
                    end
                  end.new({ name: skill_name, has: value })
                end
              end
            end

            it "adds skills to users" do
              Csvbuilder::Import::File.new(file.path, import_model, options).each do |row_model|
                row_model.skills.each do |skill_name|
                  row_model.user.skills << Skill.find_or_create_by(name: skill_name)
                end

                expect(row_model.user.skills).to be_truthy
                expect(row_model.user.skills.count).to eq(2)
                expect(row_model.user.skills.map(&:name)).to match_array(%w[Ruby Javascript])
              end
            end
          end
        end

        context "with skilled user" do
          before do
            User.last.skills << Skill.where(name: "Ruby")
          end

          after { User.last.skills.delete_all }

          describe "export" do
            let(:row_model)    { DynamicColumnsRowModel }
            let(:export_model) { DynamicColumnsExportModel }
            let(:context)      { { skills: Skill.pluck(:name) } }
            let(:sub_context)  { {} }
            let(:exporter)     { Csvbuilder::Export::File.new(export_model, context) }

            context "with bare export model" do
              it "has the right headers" do
                expect(exporter.headers).to eq(%w[Name Surname Ruby Python Javascript])
              end

              it "shows the dynamic headers" do
                expect(row_model.dynamic_column_headers(context)).to eq(%w[Ruby Python Javascript])
              end

              it "export users with their skills" do
                exporter.generate do |csv|
                  User.all.each do |user|
                    csv.append_model(user, sub_context)
                  end
                end

                expect(exporter.to_s).to eq("Name,Surname,Ruby,Python,Javascript\nJohn,Doe,1,0,0\n")
              end
            end

            context "with overriden export model" do
              let(:row_model) do
                Class.new(DynamicColumnsRowModel) do
                  class << self
                    # Safe to override
                    #
                    # @return [String] formatted header
                    def format_dynamic_column_header(header_model, column_name, _context)
                      "#{column_name.upcase}: [#{header_model}]"
                    end
                  end
                end
              end
              let(:export_model) do
                Class.new(row_model) do
                  include Csvbuilder::Export
                  class << self
                    def name
                      "DynamicColumnsExportModel"
                    end
                  end
                  def skill(skill_name)
                    source_model.skills.where(name: skill_name).exists? ? "1" : "0"
                  end
                end
              end

              it "shows the formatted dynamic headers" do
                expect(row_model.dynamic_column_headers(context)).to eq(
                  [
                    "SKILLS: [Ruby]",
                    "SKILLS: [Python]",
                    "SKILLS: [Javascript]"
                  ]
                )
              end

              it "has the right headers" do
                expect(exporter.headers).to eq(
                  [
                    "Name",
                    "Surname",
                    "SKILLS: [Ruby]",
                    "SKILLS: [Python]",
                    "SKILLS: [Javascript]"
                  ]
                )
              end

              it "exports users with their skills" do
                exporter.generate do |csv|
                  User.all.each do |user|
                    csv.append_model(user, sub_context)
                  end
                end

                expect(exporter.to_s).to eq("Name,Surname,SKILLS: [Ruby],SKILLS: [Python],SKILLS: [Javascript]\nJohn,Doe,1,0,0\n")
              end
            end
          end
        end
      end
    end
  end
end
