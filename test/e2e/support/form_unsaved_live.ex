defmodule Phoenix.LiveViewTest.E2E.FormUnsavedLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    assigns = %{}

    pre_script =
      ~H"""
      <script>
        (() => {
          if (window.unsavedFormListenerInstalled) {
            return;
          }
          window.unsavedFormListenerInstalled = true;
          window.unsavedEvents = [];

          window.addEventListener("phx:before-navigate", (event) => {
            if (document.querySelector("#unsaved-form[data-dirty='true']")) {
              window.unsavedEvents.push(event.detail);
              if (!window.confirm("You have unsaved changes. Leave without saving?")) {
                event.preventDefault();
              }
            }
          });
        })();
      </script>
      """

    {:ok, assign(socket, note: "", dirty: false, pre_script: pre_script)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"note" => note}, socket) do
    {:noreply, assign(socket, note: note, dirty: note != "")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>Unsaved form</h1>

    <.link navigate="/form-unsaved/target">Leave form</.link>

    <form id="unsaved-form" phx-change="validate" data-dirty={to_string(@dirty)}>
      <label for="unsaved-note">Unsaved note</label>
      <input id="unsaved-note" name="note" value={@note} />
      <p id="unsaved-value">Unsaved value: {@note}</p>
    </form>
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
