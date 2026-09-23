## Phoenix HTML guidelines

- Build forms from a `Phoenix.Component.to_form/2` assign (`assign(socket, form: to_form(...))`) rendered with `<.form for={@form} id="msg-form">`, accessing fields in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)
- To show literal `{` or `}` in a template, such as a code snippet in a `<pre>` or `<code>` block, annotate the parent tag with `phx-no-curly-interpolation`. Dynamic expressions still work inside it with `<%= ... %>`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

- Use list syntax for multiple or conditional class values, wrapping inline `if` calls in parens:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100")
      ]}>Text</a>

- Generate repeated template content with `:for` or `<%= for item <- @collection do %>`
- Write template comments with the HEEx comment syntax `<%!-- comment --%>`
- Interpolate values with `{...}`, both in tag attributes and tag bodies, and interpolate block constructs (`if`, `cond`, `case`, `for`) in tag bodies with `<%= ... %>`
