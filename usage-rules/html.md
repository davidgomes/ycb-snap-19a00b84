## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or `.html.heex` files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` functions to build forms. **Never** use the outdated `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for`
- When building forms, **always** use the imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access fields in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc.) when writing templates, so they can be used in tests (`<.form for={@form} id="product-form">`)
- For app-wide template imports, import/alias into the `html_helpers` block of `my_app_web.ex`, so they are available to all LiveViews, LiveComponents, and modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)
- Elixir **does not support `else if` or `elsif`**. **Always** use `cond` or `case` for multiple conditionals:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- To show literal curly braces (`{` or `}`), such as a code snippet in a `<pre>` or `<code>` block, you *must* annotate the parent tag with `phx-no-curly-interpolation`. Dynamic Elixir expressions can still be used inside it with `<%= ... %>`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

- HEEx class attrs support lists, and you **must always** use the list `[...]` syntax for multiple or conditional class values. **Always** wrap `if`'s inside `{...}` expressions with parens:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- **Always** use the HEEx comment syntax for template comments: `<%!-- comment --%>`
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but `<%= %>` **only** works within tag bodies. **Always** use `{...}` for interpolation within tag attributes and of values within tag bodies. **Always** interpolate block constructs (`if`, `cond`, `case`, `for`) within tag bodies using `<%= ... %>`:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  **Never** do this, it raises a syntax error:

      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
