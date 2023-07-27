# frozen_string_literal: true

RSpec.describe "Export With Dynamic Columns" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "Name"
      column :last_name, header: "Surname"

      dynamic_column :skills # , header: ->(name) { "SKILLS: [#{name}]" }

      class << self
        # Same as:
        # dynamic_column :skills, header: ->(name) { "SKILLS: [#{name}]" }
        def format_dynamic_column_header(header_model, column_name, _context)
          "#{column_name.upcase}: [#{header_model}]"
        end

        def name
          "DynamicColumnsRowModel"
        end
      end
    end
  end

  let(:export_model) do
    Class.new(row_model) do
      include Csvbuilder::Export

      def skill(skill_name)
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
            let(:context) { { skills: Skill.pluck(:name) } }
            let(:sub_context)  { {} }
            let(:exporter)     { Csvbuilder::Export::File.new(export_model, context) }

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
