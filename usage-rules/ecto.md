## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- `Ecto.Schema` fields use the `:string` type for both `:string` and `:text` columns, ie: `field :name, :string`
- Ecto validations only run when a change for the field exists and is not nil, so validations like `validate_number/3` need no `:allow_nil` option
- Set programmatically assigned fields, such as `user_id`, explicitly on the struct and keep them out of `cast` calls for security purposes
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied
