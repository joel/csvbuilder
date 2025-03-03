# frozen_string_literal: true

def load_data!
  {
    areas: [
      {
        name: "Area 1",
        tags: [
          { name: "Tag 1" },
          { name: "Tag 2" }
        ]
      }, {
        name: "Area 2",
        tags: [
          { name: "Tag 3" },
          { name: "Tag 4" }
        ]
      }
    ]
  }[:areas].each do |area|
    area_instance = Area.create!(name: area[:name])

    area[:tags].each do |tag|
      Tag.create!(name: tag[:name], area: area_instance)
    end
  end

  %w[Ruby Python Javascript].each do |skill_name|
    Skill.create(name: skill_name)
  end

  puts "Data loaded"
end

load_data!
