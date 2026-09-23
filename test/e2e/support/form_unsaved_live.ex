defmodule Phoenix.LiveViewTest.E2E.FormUnsavedLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"name" => ""}), saved: nil)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :patched, params["patched"])}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  def handle_event("save", %{"name" => name} = params, socket) do
    {:noreply, assign(socket, form: to_form(params), saved: name)}
  end

  @impl Phoenix.LiveView
  def render(%{live_action: :away} = assigns) do
    ~H"""
    <h1>Away</h1>
    <.link navigate="/form/unsaved">Back to form</.link>
    """
  end

  def render(assigns) do
    ~H"""
    <h1>Unsaved changes</h1>

    <.form
      for={@form}
      id="unsaved-form"
      phx-hook=".ConfirmUnsaved"
      phx-change="validate"
      phx-submit="save"
    >
      <input type="text" name={@form[:name].name} value={@form[:name].value} />
      <button type="submit">Save</button>
    </.form>

    <p :if={@saved} id="saved">Saved {@saved}</p>
    <p id="patched">Patched: {@patched}</p>

    <.link navigate="/form/unsaved/away">Navigate away</.link>
    <.link patch="/form/unsaved?patched=true">Patch</.link>
    <button phx-click={JS.navigate("/form/unsaved/away")}>JS navigate</button>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".ConfirmUnsaved">
      export default {
        mounted() {
          this.unsaved = false;
          this.el.addEventListener("input", () => (this.unsaved = true));
          this.el.addEventListener("submit", () => (this.unsaved = false));
          this.onBeforeNavigate = (e) => {
            if (this.unsaved && !confirm("You have unsaved changes. Leave anyway?")) {
              e.preventDefault();
            }
          };
          this.onBeforeUnload = (e) => this.unsaved && e.preventDefault();
          window.addEventListener("phx:before-navigate", this.onBeforeNavigate);
          window.addEventListener("beforeunload", this.onBeforeUnload);
        },
        destroyed() {
          window.removeEventListener("phx:before-navigate", this.onBeforeNavigate);
          window.removeEventListener("beforeunload", this.onBeforeUnload);
        },
      };
    </script>
    """
  end
end
