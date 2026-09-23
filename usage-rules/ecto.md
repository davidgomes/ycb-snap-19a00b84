## Ecto guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, e.g. a message that references `message.user.email`
- Remember to `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text` columns: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **does not support the `:allow_nil` option**. Ecto validations only run if a change for the given field exists and its value is not nil, so such an option is never needed
- **Always** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead, set them explicitly when creating the struct
- **Always** use `mix ecto.gen.migration migration_name_using_underscores` to generate migration files, so the correct timestamp and conventions are applied
