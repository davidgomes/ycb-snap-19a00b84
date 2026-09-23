## Phoenix LiveView guidelines

- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`
- Use function components for reusable markup, and reach for LiveComponents only when you need a component with its own state and event handling

### LiveView streams

- **Always** use LiveView streams for collections instead of assigning regular lists, to avoid memory ballooning:
  - append items - `stream(socket, :messages, [new_msg])`
  - prepend items - `stream(socket, :messages, [new_msg], at: 0)`
  - reset the stream with new items (e.g. for filtering) - `stream(socket, :messages, messages, reset: true)`
  - delete items - `stream_delete(socket, :messages, msg)`

- Set `phx-update="stream"` on the parent element and use the id of each `@streams.stream_name` entry as the DOM id of its child:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- Streams are not enumerable and do not track counts. To filter, prune, or refresh items, refetch the data and re-stream it with `reset: true`. Track counts in a separate assign
- For empty states, render a sibling with the `hidden only:block` classes. This only works if it is the only element alongside the stream items:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

- Streamed items only re-render when they are inserted again. When updating an assign that changes the content of streamed items, re-insert those items along with the assign:

      {:noreply,
       socket
       |> assign(:editing_message_id, message.id)
       |> stream_insert(:messages, message)}

### LiveView JavaScript interop

- When a JS hook manages its own DOM, also set `phx-update="ignore"` on the hook element
- Write scripts inside templates as colocated hooks, which are automatically bundled into app.js:

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

- External hooks live in `assets/js/` and are passed to the `LiveSocket` constructor in app.js next to the colocated hooks: `hooks: {...colocatedHooks, MyHook}`
- Push events to hooks with `push_event/3` and handle them with `this.handleEvent`. Hooks push events to the server with `this.pushEvent`, and `handle_event/3` can reply with `{:reply, map, socket}`

### LiveView tests

- Use `Phoenix.LiveViewTest` and `LazyHTML` (included) for assertions, and drive form tests with `render_submit/2` and `render_change/2`
- Assert on the key element IDs you added in the templates with `element/2`, `has_element?/2`, and similar functions, rather than on raw HTML or text content: `assert has_element?(view, "#my-form")`
- `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. When element selectors fail, print the actual HTML, using `LazyHTML` selectors to limit the output:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

- **Always** assign forms with `to_form/2` in the LiveView and drive the template from that form assign with the `<.input>` component, rather than from the changeset:

      <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:field]} type="text" />
      </.form>

- `to_form/2` accepts a changeset or a map of string-keyed params. Changesets compute the params name from the schema, so a `MyApp.Users.User` changeset submits `%{"user" => user_params}`. For params, pass `as: :user` to nest them
