## Phoenix LiveView guidelines

- Prefer LiveViews and function components, reaching for LiveComponents only when you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections instead of assigning regular lists, to avoid memory ballooning:
  - append items - `stream(socket, :messages, [new_msg])`
  - prepend items - `stream(socket, :messages, [new_msg], at: 0)`
  - reset the stream with new items - `stream(socket, :messages, messages, reset: true)` (e.g. for filtering items)
  - delete items - `stream_delete(socket, :messages, msg)`
- The parent element must set `phx-update="stream"` and a DOM id, and each child must use the id from `@streams.stream_name` as its DOM id:

      <div id="messages" phx-update="stream">
        <div class="hidden only:block">No messages yet</div>
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- Streams are not enumerable and do not track counts or empty states:
  - To filter, prune, or refresh items, refetch the data and re-stream it with `reset: true`
  - Track counts in a separate assign
  - Render empty states with the `hidden only:block` element shown above, which works only when it is the sole sibling of the stream comprehension
- When an assign rendered inside streamed items changes, re-insert the affected items with `stream_insert/3` so they re-render

### LiveView JavaScript interop

- Set `phx-update="ignore"` on elements whose `phx-hook` manages its own DOM
- Write scripts inside templates as colocated hooks, whose names **must** start with a `.` and which are automatically bundled into app.js:

      <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
        export default {
          mounted() {
            this.el.addEventListener("input", e => { ... })
          }
        }
      </script>

- Define external hooks in `assets/js/` and pass them to the `LiveSocket` constructor via the `hooks: {MyHook}` option
- Use `push_event/3` to send data to hooks, **always** returning or rebinding the socket it returns, and receive it in the hook with `this.handleEvent("my_event", data => ...)`. Hooks send events with `this.pushEvent("my_event", payload, reply => ...)`, which the server can answer with `{:reply, map, socket}` from `handle_event/3`

### LiveView tests

- Use `Phoenix.LiveViewTest` and `LazyHTML` (included) for assertions, and drive forms with `render_submit/2` and `render_change/2`
- Assert on outcomes through the key element IDs added in templates, using `element/2`, `has_element?/2`, and similar, such as `assert has_element?(view, "#my-form")`, rather than on raw HTML or text content
- When debugging selectors, print only the relevant HTML with `LazyHTML`:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

- **Always** assign forms via `to_form/2` in the LiveView, render them with `<.form for={@form} id="todo-form">` and `<.input field={@form[:field]} type="text" />`, and drive all template references from the form assign, as in `@form[:field]`
- `to_form/2` accepts either a params map with string keys (`to_form(params)`, or `to_form(user_params, as: :user)` to nest them) or a changeset, from which the data, params, errors, and `:as` name are derived. For example, a `%MyApp.Users.User{}` changeset submits its params under `%{"user" => user_params}`
