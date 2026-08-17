defmodule Phoenix.LiveViewTest.E2E.FormUnsavedLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    assigns = %{}

    pre_script =
      ~H"""
      <script type="module">
        (() => {
          if (window.unsavedFormListenersInstalled) {
            return;
          }

          window.unsavedFormListenersInstalled = true;
          window.unsavedEvents = window.unsavedEvents || [];

          const hasUnsavedChanges = () =>
            document.querySelector("#unsaved-form[data-dirty='true']") !== null;

          window.addEventListener("phx:before-navigate", (event) => {
            if (hasUnsavedChanges()) {
              window.unsavedEvents.push({ type: "phx", detail: event.detail });

              if (!window.confirm("You have unsaved changes. Leave without saving?")) {
                event.preventDefault();
              }
            }
          });

          window.addEventListener("beforeunload", (event) => {
            if (hasUnsavedChanges()) {
              window.unsavedEvents.push({ type: "beforeunload" });
              event.preventDefault();
              event.returnValue = "";
            }
          });
        })();
      </script>
      """

    socket
    |> assign(:note, "")
    |> assign(:dirty, false)
    |> assign(:pre_script, pre_script)
    |> then(&{:ok, &1})
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"note" => note}, socket) do
    {:noreply, assign(socket, note: note, dirty: note != "")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    {@pre_script}

    <h1>Unsaved form</h1>

    <.link navigate="/form-unsaved/target">Leave form</.link>

    <form id="unsaved-form" data-dirty={@dirty} phx-change="validate">
      <label for="unsaved-note">Unsaved note</label>
      <input type="text" id="unsaved-note" name="note" value={@note} />
    </form>

    <p id="unsaved-value">Unsaved value: {@note}</p>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.FormUnsavedLive.Target do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>Unsaved form target</h1>
    """
  end
end
