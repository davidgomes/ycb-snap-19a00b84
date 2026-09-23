defmodule Phoenix.LiveViewTest.E2E.Issue2835Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/2835

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(consumed: [], submitted?: false)
     |> allow_upload(:documents,
       accept: :any,
       auto_upload: true,
       max_entries: 2,
       progress: &__MODULE__.handle_progress/3
     )}
  end

  def handle_progress(:documents, %{done?: true} = entry, socket) do
    name = consume_uploaded_entry(socket, entry, fn _meta -> {:ok, entry.client_name} end)
    {:noreply, update(socket, :consumed, &Enum.sort([name | &1]))}
  end

  def handle_progress(:documents, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, submitted?: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="issue-2835">
      <form id="upload-form" phx-change="validate" phx-submit="submit">
        <.live_file_input upload={@uploads.documents} />
        <button type="submit">Submit</button>
      </form>

      <p id="submitted">submitted: {@submitted?}</p>
      <p id="consumed">consumed: {Enum.join(@consumed, ",")}</p>
      <p :for={error <- upload_errors(@uploads.documents)} class="upload-error">
        {inspect(error)}
      </p>

      <article
        :for={entry <- @uploads.documents.entries}
        class="upload-entry"
        data-name={entry.client_name}
      >
        <span>{entry.client_name}: {entry.progress}%</span>
        <button type="button" phx-click="cancel" phx-value-ref={entry.ref}>Cancel</button>
      </article>
    </div>
    """
  end
end
