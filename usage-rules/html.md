## Phoenix HTML guidelines

- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)
- Use the class list syntax for multiple or conditional class values: `class={["px-2 text-white", @some_flag && "py-5", if(@other_condition, do: "border-red-500", else: "border-blue-100")]}`
- To render literal curly braces, such as a code snippet in a `<pre>` or `<code>` block, annotate the parent tag with `phx-no-curly-interpolation`. Dynamic Elixir expressions can still be used inside it with `<%= ... %>` syntax
