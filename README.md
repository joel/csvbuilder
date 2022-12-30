# Csvbuilder

[Csvbuilder](https://rubygems.org/gems/csvbuilder-collection) is a wrapper for a collection of libraries that lets you export and import CSV data easily.

It carries [integration specs](https://github.com/joel/csvbuilder/tree/main/spec/integrations) which are perfect for understanding all the feature of `csvbuilder` and having a concrete example of how each part work.

1. [csvbuilder-core](https://rubygems.org/gems/csvbuilder-core)
2. [csvbuilder-dynamic-columns-core](https://rubygems.org/gems/csvbuilder-dynamic-columns-core)

This library was written to be extendable in mind. The extremely modular set of libraries lets you extend your application's functionalities to best suit your need.

Feel free to install only what your application needs.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add csvbuilder

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install csvbuilder

## Usage

# Model

The library comes we a nice simple DSL. The model should correspond to the headers and cells of a CSV row.

```ruby
class UserRowModel
  include Csvbuilder::Model

  column :first_name
  column :last_name
end
```

Generally, the defined columns will match your database columns. But it is definitely not necessary.

The model is meant to be the standard area for import and export. We'll see in the next section how those two differ.

[More on Model](https://github.com/joel/csvbuilder-core)

# Exporting

If you want to add a piece of information for export only, like in the following example, the Corporate Email, you can compute data in the Export Class.

```ruby
class UserExportModel < UserRowModel
  include Csvbuilder::Export

  column :email, header: "Corporate Email"

  def email
    "#{first_name}.#{last_name}@example.co.uk".downcase
  end
end
```

## How to export

You need to provide both object collection and exporter class as follow:

```ruby
collection = [OpenStruct.new(first_name: "John", last_name: "Doe", full_name: "John Doe")]

exporter = Csvbuilder::Export::File.new(UserExportModel, context = {})

exporter.headers
# => "First Name", "Last Name", "Full Name", "Email"

exporter.generate do |csv|
  collection.each do |user|
    csv.append_model(user, another_context: true)
  end
end
# => "First Name,Last Name,Full Name,Email\nJohn,Doe,John Doe,john.doe@example.co.uk\n"
```

[More on Exporter](https://github.com/joel/csvbuilder-exporter)

# Importing

The importing part is the more critical part. It carries validations to handle complex use cases. You have all the power of the `ActiveModel::Validations`. The validations happen in the importer class, and it acts as policies. You can couple them with the model itself, though. It is still recommended to handle model errors at a higher level to not pair the `ImportModel` with the model too much.

```ruby
class UserImportModel < UserRowModel
  include Csvbuilder::Import

  validates :first_name, presence: true, length: { minimum: 2 }
  validates :last_name, presence: true, length: { minimum: 2 }

  def full_name
    "#{first_name} #{last_name}"
  end

  def user
    User.new(first_name: first_name, last_name: last_name, full_name: full_name)
  end

  # Skip if the row is not valid, the user is not valid or the user already exists
  def skip?
    super || !user.valid? || user.exists?
  end
end
```

## How to import

For importing, you must provide the CSV file and the Import Class. The `Import::File` will skip an invalid importer, a not valid user or an already existing user.

```ruby
csv_source = [
  ["First name", "Last name"],
  ["John"      , "Doe"      ],
]

CSV.generate do |csv|
  csv_source.each { |row| csv << row }
end

file = Tempfile.new(["input_file", ".csv"])

Csvbuilder::Import::File
  .new(file.path, UserImportModel, options = {}).each do |row_model|
	  row_model.user.save
end
```

[More on Importer](https://github.com/joel/csvbuilder-importer)

# Dynamic columns

The headers are dynamic and take a collection, so it doesn’t need a strict definition like other columns. Dynamic columns are a relation between header value and cell value.

[More on dynamic columns](https://github.com/joel/csvbuilder-dynamic-columns-core)

## Credits

This project is inspired by the open-source library [CsvRowModel](https://github.com/finalcad/csv_row_model) written by [Steve Chung](https://github.com/s12chung). Unfortunately, this library is unmaintained and currently broken, and it depends on other unmaintained libraries. The purpose is to keep the core concepts and the architecture, removing all non-essential features and unmaintained dependencies and adding test coverage with Rails and Ruby matrices to track any broken version, past and future. Splitting the library into several gems lets projects use only the needed parts.

## Dependencies

1. [csvbuilder-core](https://rubygems.org/gems/csvbuilder-core)
2. [csvbuilder-exporter](https://rubygems.org/gems/csvbuilder-exporter)
3. [csvbuilder-importer](https://rubygems.org/gems/csvbuilder-importer)
4. [csvbuilder-dynamic-columns-core](https://rubygems.org/gems/csvbuilder-dynamic-columns-core)
5. [csvbuilder-dynamic-columns-exporter](https://rubygems.org/gems/csvbuilder-dynamic-columns-exporter)
6. [csvbuilder-dynamic-columns-importer](https://rubygems.org/gems/csvbuilder-dynamic-columns-importer)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joel/csvbuilder. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/csvbuilder/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Csvbuilder project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/csvbuilder/blob/main/CODE_OF_CONDUCT.md).
