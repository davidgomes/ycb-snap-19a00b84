## Phoenix LiveView guidelines

- Navigate with `<.link navigate={href}>` and `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` in LiveViews
- Prefer function components, reaching for LiveComponents only when you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. Router `scope` blocks prefix their alias to every route within them, and the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- Use LiveView streams for collections to avoid memory ballooning:
  - append items - `stream(socket, :messages, [new_msg])`
  - prepend items - `stream(socket, :messages, [new_msg], at: 0)`
  - reset the stream with new items - `stream(socket, :messages, messages, reset: true)`
  - update an item - `stream_insert(socket, :messages, msg)`
  - delete an item - `stream_delete(socket, :messages, msg)`

- Render streams inside a parent element with a DOM id and `phx-update="stream"`, using each entry's id as the child's DOM id:

      <div id="messages" phx-update="stream">
        <div class="hidden only:block">No messages yet</div>
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

  The `hidden only:block` empty state works only when it is the sole element alongside the stream comprehension.

- Streams are not enumerable and keep no items on the server. To filter or refresh items, refetch the data and re-stream it with `reset: true`. To display counts or emptiness in the LiveView, track them in separate assigns
- When an assign changes content rendered inside streamed items, re-insert the affected items with `stream_insert/3` so they re-render

### LiveView JavaScript interop

- Set `phx-update="ignore"` on any `phx-hook` element whose hook manages its own DOM
- Write scripts inside templates as colocated hooks, whose names start with a `.` and are bundled into app.js automatically:

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

- Place external hooks in `assets/js/` and pass them to the `LiveSocket` constructor with `hooks: { MyHook }`
- Push events to hooks with `push_event/3`, keeping the returned socket (`{:noreply, push_event(socket, "my_event", %{...})}`), and handle them in the hook with `this.handleEvent("my_event", data => ...)`
- Push events from hooks with `this.pushEvent("my_event", payload, reply => ...)`, replying from the server with `{:reply, %{...}, socket}`

### LiveView tests

- Write assertions with `Phoenix.LiveViewTest` and `LazyHTML` (included)
- Drive form tests with `render_submit/2` and `render_change/2`
- Select elements by the DOM IDs added in templates with `element/2` and `has_element?/2` (`assert has_element?(view, "#my-form")`), favoring the presence of key elements over raw HTML or text content
- When debugging failing selectors, inspect only the relevant part of the rendered HTML:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

- Create forms from changesets with `to_form(changeset)`, which derives the data, params, errors, and name from the changeset. For a `MyApp.Users.User` changeset, submitted params arrive under `%{"user" => user_params}`
- Create forms from string-keyed params with `to_form(params)`, or `to_form(user_params, as: :user)` to nest them under a name
- Drive the UI from the form assign, rendering fields with the imported `<.input>` component:

      <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:field]} type="text" />
      </.form>
