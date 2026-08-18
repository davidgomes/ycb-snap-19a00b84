defmodule PetalComponents.DataTable.Selection do
  @moduledoc """
  Row selection for `PetalComponents.DataTable`: the selected ids plus
  the event grammar that maintains them, so a selection handler is one
  call in either wiring mode.

      def handle_event("select", params, socket) do
        ids = Enum.map(socket.assigns.rows, & &1.id)
        selected = Selection.handle_op(socket.assigns.selected, params, ids: ids)
        {:noreply, assign(socket, selected: selected)}
      end

  Selection deliberately lives OUTSIDE `DataTable.State`. State is the
  query - sorts, filters, page - and round-trips through the URL, while
  a selection is neither a query input nor something a shared link
  should carry. Keeping it in its own assign is also what makes it
  survive link mode: sorts and page changes patch the URL and rebuild
  the state from params, and never touch the selection.

  ## The ops

    * `%{"op" => "select", "id" => id, "checked" => "true" | "false"}` -
      one row's checkbox
    * `%{"op" => "select_page", "checked" => "true" | "false"}` - the
      tri-state header, over the ids of the rendered page
    * `%{"op" => "clear_selection"}` - the selection toolbar's dismiss

  ## Ids stay your ids

  `phx-value-*` params are always strings, so `:ids` - the ids of the
  rows currently on screen, in whatever type they really are - is how
  `"7"` resolves back to `7`. Ids the page does not hold are dropped:
  the same whitelist stance `State.from_params/2` takes with fields, so
  a stale click can never add an id your rows never had.
  """

  @doc """
  Applies one selection op payload, returning the new selected ids
  (insertion-ordered, deduplicated).

  Options:

    * `:ids` - the ids of the currently rendered rows. The `select` and
      `select_page` ops resolve against it; without it they are no-ops.
  """
  def handle_op(selected, params, opts \\ []) when is_list(selected) and is_map(params) do
    ids = Keyword.get(opts, :ids, [])

    case params do
      %{"op" => "select", "id" => id} ->
        case Enum.find(ids, &(key(&1) == key(id))) do
          nil -> selected
          found -> put(selected, found, checked?(params))
        end

      %{"op" => "select_page"} ->
        if checked?(params),
          do: Enum.reduce(ids, selected, &put(&2, &1, true)),
          else: Enum.reject(selected, &member?(ids, &1))

      %{"op" => "clear_selection"} ->
        []

      _other ->
        selected
    end
  end

  @doc """
  Whether `id` is selected, compared as strings - what the component
  renders its checkboxes from, and what makes a hand-built selection of
  param strings line up with integer row ids.
  """
  def member?(selected, id) when is_list(selected) do
    Enum.any?(selected, &(key(&1) == key(id)))
  end

  defp put(selected, id, true) do
    if member?(selected, id), do: selected, else: selected ++ [id]
  end

  defp put(selected, id, false), do: Enum.reject(selected, &(key(&1) == key(id)))

  # a checkbox posts "true" through phx-value and "on" from inside a
  # form - anything else reads as unchecked
  defp checked?(%{"checked" => checked}), do: to_string(checked) in ~w(true on 1)
  defp checked?(_params), do: false

  # ids ride phx-value, so they are scalars by construction: stringify
  # both sides and the integer 7 and the "7" that comes back are one id
  defp key(id) when is_binary(id), do: id
  defp key(id), do: to_string(id)
end
