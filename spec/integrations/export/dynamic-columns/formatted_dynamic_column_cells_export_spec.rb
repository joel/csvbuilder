# frozen_string_literal: true

RSpec.describe "Export With Dynamic Columns" do
  let(:row_model) do
    Class.new do
      include Csvbuilder::Model

      column :first_name, header: "Name"
      column :last_name, header: "Surname"

      dynamic_column :skills

      class << self
        def name
          "DynamicColumnsRowModel"
        end

        # NOTE: This is apply to regular cells, not dynamic column cells
        # dynamic column cells are formatted by `format_dynamic_column_cells`
        def format_cell(cell, _column_name, _context)
          "- #{cell} -"
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
      end
    end
  end

  let(:export_model) do
    Class.new(row_model) do
      include Csvbuilder::Export

      def skill(skill_name)
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
            let(:context)      { { skills: Skill.pluck(:name) } }
            let(:sub_context)  { {} }
            let(:exporter)     { Csvbuilder::Export::File.new(export_model, context) }

            it "has the right headers" do
              expect(row_model.dynamic_column_headers(context)).to eq(%w[Ruby Python Javascript])
            end

            it "shows the dynamic headers" do
              expect(row_model.dynamic_column_headers(context)).to eq(%w[Ruby Python Javascript])
            end

            it "export users with their skills" do
              exporter.generate do |csv|
                User.all.each do |user|
                  row_model = csv.append_model(user, sub_context)

                  # There is only one iteration here.

                  expect(row_model.attribute_objects[:skills]).to be_a Csvbuilder::Export::DynamicColumnAttribute

                  # Formatted values with format_dynamic_column_cells
                  expect(row_model.attribute_objects[:skills].value).to eql %w[1 0 0]

                  # Unformatted values
                  expect(row_model.attribute_objects[:skills].unformatted_value).to eql [true, false, false]
                  expect(row_model.attribute_objects[:skills].source_cells).to eql [true, false, false]

                  # Formatted values with format_cell
                  expect(row_model.attribute_objects[:skills].formatted_cells).to eql ["- true -", "- false -", "- false -"]
                end
              end

              expect(exporter.to_s).to eq("Name,Surname,Ruby,Python,Javascript\n- John -,- Doe -,1,0,0\n")
            end
          end
        end
      end
    end
  end
end
