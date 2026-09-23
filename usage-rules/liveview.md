## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use `<.link navigate={href}>` and `<.link patch={href}>` in templates, and the `push_navigate` and `push_patch` functions in LiveViews
- **Avoid LiveComponents** unless you have a strong, specific need for them
- LiveViews should be named with a `Live` suffix, like `AppWeb.WeatherLive`. The default `:browser` scope in the router is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections instead of assigning regular lists, to avoid memory ballooning and runtime termination:
  - append N items - `stream(socket, :messages, [new_msg])`
  - reset the stream with new items (e.g. for filtering) - `stream(socket, :messages, messages, reset: true)`
  - prepend items - `stream(socket, :messages, [new_msg], at: 0)`
  - delete items - `stream_delete(socket, :messages, msg)`
- The template must set `phx-update="stream"` and a DOM id on the parent element, and use the id from `@streams.stream_name` as the DOM id of each child:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- Streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. To filter, prune, or refresh items on the UI, you **must refetch the data and re-stream the entire collection, passing `reset: true`**
- Streams *do not support counting or empty states*. Track counts in a separate assign. For empty states, you can use Tailwind classes, as long as the empty state is the only other element alongside the stream items:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

- When updating an assign that changes content inside streamed items, you **must** also re-insert the affected items with `stream_insert/3`
- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- When a `phx-hook` manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide a unique DOM id alongside `phx-hook`, otherwise a compiler error will be raised
- **Never** write raw `<script>` tags in HEEx. **Always** use colocated hooks (`:type={Phoenix.LiveView.ColocatedHook}`) for scripts inside templates. They are automatically bundled into `app.js` and their names **must always** start with a `.` prefix:

      <input type="text" id="user-phone-number" phx-hook=".PhoneNumber" />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
        export default {
          mounted() {
            this.el.addEventListener("input", e => { ... })
          }
        }
      </script>

- External hooks must be placed in `assets/js/` and passed to the `LiveSocket` constructor: `new LiveSocket("/live", Socket, {hooks: {MyHook}})`
- Use `push_event/3` to push events to the client and **always** return or rebind the socket, e.g. `{:noreply, push_event(socket, "my_event", %{...})}`. Hooks handle them with `this.handleEvent("my_event", data => ...)`
- Hooks push events to the server with `this.pushEvent("my_event", payload, reply => ...)`, which `handle_event/3` can reply to by returning `{:reply, %{...}, socket}`

### LiveView tests

- Use `Phoenix.LiveViewTest` and `LazyHTML` (included) for your assertions, and drive form tests with `render_submit/2` and `render_change/2`
- **Always** reference the key element IDs from your templates in tests, using functions like `element/2` and `has_element?/2`: `assert has_element?(view, "#my-form")`. **Never** test against raw HTML
- Favor testing for the presence of key elements and for outcomes over text content, which can change, and implementation details
- `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the actual HTML structure. When debugging selector failures, print only the relevant HTML with `LazyHTML`:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

- **Always** assign a form via `to_form/2` in the LiveView and use `<.form>` with the `<.input>` component in the template. Give each form an explicit, unique DOM id:

      <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:field]} type="text" />
      </.form>

- `to_form/2` accepts either a map of params with string keys (use `to_form(user_params, as: :user)` to nest them) or a changeset, from which the data, params, errors, and `:as` name are derived (e.g. params for a `MyApp.Users.User` changeset are submitted under `%{"user" => user_params}`)
- You are FORBIDDEN from accessing the changeset in the template (`<.form for={@changeset}>` or `@changeset[:field]`) as it will cause errors
- **Never** use `<.form let={f} ...>`. Drive all form references from the form assign, as in `@form[:field]`
