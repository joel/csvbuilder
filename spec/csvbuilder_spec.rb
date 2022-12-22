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
          let(:csv_source) do
            [
              ["First name", "Last name", "Ruby", "Python", "Javascript"],
              %w[John Doe 1 0 1]
            ]
          end

          it "addses skills to users" do
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

        context "with skilled user" do
          before do
            User.last.skills << Skill.where(name: "Ruby")
          end

          after { User.last.skills.delete_all }

          describe "export" do
            let(:context)     { { skills: Skill.pluck(:name) } }
            let(:sub_context) { {} }
            let(:exporter)    { Csvbuilder::Export::File.new(export_model, context) }
            let(:row_model)   { DynamicColumnsRowModel }

            context "with bare export model" do
              let(:export_model) { DynamicColumnsExportModel }

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
                    def format_dynamic_column_header(header_model, column_name, context)
                      {
                        header_model: header_model,
                        column_name: column_name,
                        context: context.to_h
                      }
                    end
                  end
                end
              end

              it "shows the dynamic headers" do
                expect(row_model.dynamic_column_headers(context)).to eq(
                  [{ column_name: :skills,
                     context: { skills: %w[Ruby Python Javascript] },
                     header_model: "Ruby" },
                   { column_name: :skills,
                     context: { skills: %w[Ruby Python Javascript] },
                     header_model: "Python" },
                   { column_name: :skills,
                     context: { skills: %w[Ruby Python Javascript] },
                     header_model: "Javascript" }]
                )
              end
              # it "should have the right headers" do
              #   expect(exporter.headers).to eq(%w[Name Surname Ruby Python Javascript])
              # end

              # it "should export users with their skills" do
              #   expect(exporter.headers).to eq(%w[Name Surname Ruby Python Javascript])

              #   exporter.generate do |csv|
              #     User.all.each do |user|
              #       csv.append_model(user, sub_context)
              #     end
              #   end

              #   expect(exporter.to_s).to eq("Name,Surname,Ruby,Python,Javascript\nJohn,Doe,1,0,0\n")
              # end
            end
          end
        end
      end
    end
  end
end
