## Phoenix LiveView guidelines

- Use function components and LiveViews by default, and LiveComponents only when you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. Router `scope` blocks prefix their alias to all routes within them and the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections, instead of assigning regular lists, to avoid memory ballooning:
  - append items - `stream(socket, :messages, [new_msg])`
  - prepend items - `stream(socket, :messages, [new_msg], at: 0)`
  - reset the stream with new items - `stream(socket, :messages, messages, reset: true)` (e.g. for filtering items)
  - delete items - `stream_delete(socket, :messages, msg)`
- The template must set `phx-update="stream"` and a DOM id on the parent element, and use the id of each `@streams.stream_name` entry as the DOM id of its child:

      <div id="messages" phx-update="stream">
        <div class="hidden only:block">No messages yet</div>
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

  The `hidden only:block` empty state only works if it is the only element alongside the stream for-comprehension
- Streams are *not* enumerable and do not support counting. To filter, prune, or refresh items, refetch the data and re-stream it with `reset: true`. To display a count, track it in a separate assign
- When an assign that affects the content of streamed items changes, re-insert the affected items with `stream_insert/3` so they re-render with the updated assign

### LiveView JavaScript interop

- When a `phx-hook` manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- Write scripts inside templates as colocated hooks, whose names start with a `.` prefix, instead of raw `<script>` tags, which are incompatible with LiveView. Colocated hooks are automatically bundled into app.js:

      <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
        export default {
          mounted() {
            this.el.addEventListener("input", e => {
              let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
              if(match) {
                this.el.value = `${match[1]}-${match[2]}-${match[3]}`
              }
            })
          }
        }
      </script>

- External hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the `LiveSocket` constructor with `hooks: {MyHook}`
- Use `push_event/3` to push events from the server, which hooks handle with `this.handleEvent("my_event", data => ...)`. Hooks push events to the server with `this.pushEvent("my_event", payload, reply => ...)`, which `handle_event/3` can answer with `{:reply, map, socket}`

### LiveView tests

- Use `Phoenix.LiveViewTest` and `LazyHTML` (included) for your assertions, and drive form tests with `render_change/2` and `render_submit/2`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) in templates and reference them in tests with `element/2` and `has_element?/2`, such as `assert has_element?(view, "#product-form")`. Assert on the presence of key elements rather than on raw HTML or text content, which can change
- When debugging selector failures, print the actual HTML narrowed down with `LazyHTML` selectors:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

- **Always** drive forms from a form assigned in the LiveView with `to_form/2` and, in the template, access its fields as `@form[:field]` with the `<.input>` component. The template should only reference the form assign, not the changeset:

      <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:field]} type="text" />
      </.form>

- `to_form/2` accepts changesets or params:
  - For changesets, the data, params, errors, and `:as` option are derived from it. For example, a `%MyApp.Users.User{}` changeset submits its params as `%{"user" => user_params}`
  - For params from `handle_event/3`, which have string keys, use `to_form(params)` or nest them with `to_form(user_params, as: :user)`
