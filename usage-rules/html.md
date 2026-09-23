## Phoenix HTML guidelines

- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)
- HEEx requires the `phx-no-curly-interpolation` attribute on the parent tag to render literal `{` and `}`, such as code snippets inside `<pre>` or `<code>`. Dynamic expressions can still be used within it via `<%= ... %>`
- Use the list syntax for multiple or conditional class values, wrapping inline `if`'s in parens: `class={["px-2 text-white", @some_flag && "py-5", if(@other_condition, do: "border-red-500", else: "border-blue-100")]}`
- Use `{...}` for interpolation within tag attributes and tag bodies, and `<%= ... %>` for block constructs (`if`, `cond`, `case`, `for`) within tag bodies
- Render collections with `:for` or `<%= for item <- @collection do %>` comprehensions
- Use HEEx comments (`<%!-- comment --%>`) for template comments
