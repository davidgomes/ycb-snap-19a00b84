## Phoenix LiveView guidelines

- Prefer LiveViews and function components, reaching for LiveComponents only when you have a strong, specific need for them

### Forms

- Drive forms from a `Phoenix.Component.to_form/2` assign in the LiveView, derived from a changeset (`assign(socket, form: to_form(changeset))`) or from string-keyed params (`to_form(params, as: :user)`)
- Render forms with `<.form for={@form} id="todo-form">` and the `<.input>` component, driving every field from the form assign via `@form[:field]`:

      <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" />
      </.form>

- Changeset forms compute the `:as` name from the schema, so a `MyApp.Users.User` changeset submits its params under `%{"user" => user_params}`

### Streams

- Use streams for collections instead of assigning regular lists, to avoid memory ballooning:
  - append items - `stream(socket, :messages, [new_msg])`
  - prepend items - `stream(socket, :messages, [new_msg], at: 0)`
  - reset the stream with new items (e.g. for filtering) - `stream(socket, :messages, messages, reset: true)`
  - delete items - `stream_delete(socket, :messages, msg)`
- In the template, set `phx-update="stream"` and a DOM id on the parent element, and use the stream's id as the DOM id of each child:

      <div id="messages" phx-update="stream">
        <div class="hidden only:block">No messages yet</div>
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

  The `hidden only:block` empty state only works when it is the sole element alongside the stream comprehension
- Streams are not enumerable and do not track counts. To filter, prune, or refresh items, refetch the data and re-stream it with `reset: true`. Track counts or emptiness in separate assigns
- When an assign that changes the content of streamed items is updated, re-insert the affected items with `stream_insert/3` so they re-render

### JavaScript interop

- Write scripts inside templates as colocated hooks, with names starting with a `.`. They are bundled into `app.js` automatically:

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

- Place external hooks in `assets/js/` and pass them to the `LiveSocket` constructor via the `hooks` option
- Set `phx-update="ignore"` on any `phx-hook` element whose hook manages its own DOM
- Push data to hooks with `push_event/3`, handled in the hook by `this.handleEvent`. Hooks can push events to the server with `this.pushEvent`, which receives the reply of a `{:reply, map, socket}` return from `handle_event/3`

### Tests

- Use `Phoenix.LiveViewTest` and `LazyHTML` (included) for assertions, driving forms with `render_change/2` and `render_submit/2`
- Assert on key elements through the DOM IDs added in templates, using `element/2` and `has_element?/2` (`assert has_element?(view, "#my-form")`), instead of raw HTML or text content
- Focus on testing outcomes rather than implementation details, splitting major test cases into small, isolated files
- When debugging selector failures, print the actual HTML narrowed with `LazyHTML` selectors:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")
