# frozen_string_literal: true

RSpec.describe "Export With Dynamic Columns" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "Name"
      column :last_name, header: "Surname"

      dynamic_column :skills, as: :abilities

      class << self
        def name
          "DynamicColumnsRowModel"
        end
      end
    end
  end

  let(:export_model) do
    Class.new(row_model) do
      include Csvbuilder::Export

      def ability(skill_name)
        source_model.skills.where(name: skill_name).exists? ? "1" : "0"
      end

      class << self
        def name
          "DynamicColumnsExportModel"
        end
      end
    end
  end

  context "with user" do
    before do
      User.create(first_name: "John", last_name: "Doe", full_name: "John Doe")
    end

    context "with skills" do
      before do
        %w[Ruby Python Javascript].each do |skill_name|
          Skill.create(name: skill_name)
        end
      end

      context "with dynamic columns" do
        context "with skilled user" do
          before do
            User.last.skills << Skill.where(name: "Ruby")
          end

          describe "export" do
            let(:context)      { { abilities: Skill.pluck(:name) } }
            let(:sub_context)  { {} }
            let(:exporter)     { Csvbuilder::Export::File.new(export_model, context) }

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
        end
      end
    end
  end
end
