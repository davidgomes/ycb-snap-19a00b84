## Phoenix HTML guidelines

- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)
- To show literal curly braces in HEEx, such as a code snippet in a `<pre>` or `<code>` block, annotate the parent tag with `phx-no-curly-interpolation`. Within it, `{` and `}` need no escaping and dynamic Elixir expressions can still be used with `<%= ... %>` syntax:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>
