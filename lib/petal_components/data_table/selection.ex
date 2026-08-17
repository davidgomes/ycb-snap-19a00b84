defmodule PetalComponents.DataTable.Selection do
  @moduledoc """
  Row-selection as a plain set of ids, plus the tiny event grammar
  `<.data_table selectable>` posts through `on_select` - mirrors
  `State.handle_op/3`'s one-liner ergonomics, but kept as its own
  module because selection is local UI state, never URL state: unlike
  `State`, it never round-trips through `to_params/1`.

      def handle_event("select", params, socket) do
        selected = Selection.handle_op(socket.assigns.selected, params)
        {:noreply, assign(socket, :selected, selected)}
      end

  Ids always compare as strings - `phx-click` values arrive that way,
  and `row_id` results are normalized on the way in - so `new/0` and
  every function here return/accept sets of strings.

  ## Grammar

  `%{"op" => "toggle", "id" => id}` flips one row. `%{"op" =>
  "toggle_page", "ids" => ids}` is the tri-state header's own click:
  selects every id unless all of them are already selected, in which
  case it deselects them all. `%{"op" => "clear"}` empties the
  selection. Unknown ops leave the selection unchanged.
  """

  @type t :: MapSet.t(String.t())

  @doc "An empty selection - the default `selected` value."
  @spec new() :: t()
  def new, do: MapSet.new()

  @doc "Normalizes any enumerable of ids (a MapSet, a list, integers or strings) into a string-keyed set."
  @spec normalize(Enumerable.t()) :: t()
  def normalize(selected), do: MapSet.new(selected, &to_string/1)

  @doc "Applies one `on_select` op payload. Unknown ops leave the selection unchanged."
  @spec handle_op(t(), map()) :: t()
  def handle_op(selected, params)

  def handle_op(selected, %{"op" => "toggle", "id" => id}) do
    id = to_string(id)

    if MapSet.member?(selected, id) do
      MapSet.delete(selected, id)
    else
      MapSet.put(selected, id)
    end
  end

  def handle_op(selected, %{"op" => "toggle_page", "ids" => ids}) do
    ids = normalize(ids)

    if MapSet.subset?(ids, selected) do
      MapSet.difference(selected, ids)
    else
      MapSet.union(selected, ids)
    end
  end

  def handle_op(_selected, %{"op" => "clear"}), do: new()
  def handle_op(selected, _other), do: selected

  @doc """
  The tri-state header status for a page of ids: `:all` (every one
  selected - the header renders checked), `:none` (the header renders
  unchecked), or `:some` (a partial page - the header renders
  indeterminate).
  """
  @spec page_state(t(), [String.t()]) :: :all | :some | :none
  def page_state(_selected, []), do: :none

  def page_state(selected, page_ids) do
    ids = normalize(page_ids)

    cond do
      MapSet.subset?(ids, selected) -> :all
      Enum.any?(ids, &MapSet.member?(selected, &1)) -> :some
      true -> :none
    end
  end
end
