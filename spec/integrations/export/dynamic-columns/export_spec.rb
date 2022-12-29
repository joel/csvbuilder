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

        def format_dynamic_column_cells(cells, _column_name, _context)
          cells.map do |cell|
            case cell
            when true
              "1"
            when false
              "0"
            else
              "N/A"
            end
          end
        end

        def format_dynamic_column_header(header_model, column_name, _context)
          "#{column_name}: [#{header_model}]"
        end
      end
    end
  end

  let(:export_model) do
    Class.new(row_model) do
      include Csvbuilder::Export

      def ability(skill_name)
        source_model.skills.where(name: skill_name).exists?
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

    after { User.delete_all }

    context "with skills" do
      before do
        %w[Ruby Python Javascript].each do |skill_name|
          Skill.create(name: skill_name)
        end
      end

      after { Skill.delete_all }

      context "with dynamic columns" do
        context "with skilled user" do
          before do
            User.last.skills << Skill.where(name: "Ruby")
          end

          after { User.last.skills.delete_all }

          describe "export" do
            let(:context)      { { abilities: Skill.pluck(:name) } }
            let(:sub_context)  { {} }
            let(:exporter)     { Csvbuilder::Export::File.new(export_model, context) }

            it "has the right headers" do
              expect(exporter.headers).to eq(["Name", "Surname", "skills: [Ruby]", "skills: [Python]",
                                              "skills: [Javascript]"])
            end

            it "shows the dynamic headers" do
              expect(row_model.dynamic_column_headers(context)).to eq(["skills: [Ruby]", "skills: [Python]",
                                                                       "skills: [Javascript]"])
            end

            it "export users with their skills" do
              exporter.generate do |csv|
                User.all.each do |user|
                  csv.append_model(user, sub_context)
                end
              end

              expect(exporter.to_s).to eq("Name,Surname,skills: [Ruby],skills: [Python],skills: [Javascript]\nJohn,Doe,1,0,0\n")
            end
          end
        end
      end
    end
  end
end
