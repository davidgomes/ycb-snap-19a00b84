## Phoenix HTML guidelines

- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)
- To render literal `{` and `}` characters, such as code snippets in `<pre>` or `<code>` blocks, annotate the parent tag with `phx-no-curly-interpolation`. Dynamic Elixir expressions can still be used within it with `<%= ... %>` syntax:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>
