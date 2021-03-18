# oobium gen
Code generation tools and utilities.

Currently consists of model generator for the oobium connected Database.

## Usage
`$ dart run runner.dart -client <schema_directory>`

## Schema files
All files in the `<schema_directory>` that end with '.schema' will be parsed and used to generate a database definition with the corresponding name. For example, `/data/users.schema` will generate a database definition `UsersData` in the file `/data/users.schema.gen.models.dart`.

## Schema file format
The schema file is simply a list of models and their attribute. It is intentionally very simple and limited.

Each model starts at the beginning of a new line; each attribute of the model starts on a new indented line. Attributes are added to the model until a blank line is found. For example:

    User
      name String(required)
      avatar String

This creates a `User` model (dart class) with two attributes, each of type `String`.

The format for each attribute is: `<name> <type>(<metadata>)`. The `type` can be any built-in dart type or any model defined in the schema (importing types is not supported). `metadata` is a comma separated list of optional features, such as:
- required: annotates with @required (marked non-null in the upcoming sound null safety release)
- resolve: obsolete
- scaffold: include attribute in the generated scaffolding (not currently implemented)
