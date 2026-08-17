defmodule FreeObanUiWeb.JobLive.Index do
  defdelegate mount(params, session, socket), to: FreeObanUiWeb.ObanLive.Index
  defdelegate handle_params(params, uri, socket), to: FreeObanUiWeb.ObanLive.Index
  defdelegate handle_event(event, params, socket), to: FreeObanUiWeb.ObanLive.Index
  defdelegate handle_info(msg, socket), to: FreeObanUiWeb.ObanLive.Index
  defdelegate render(assigns), to: FreeObanUiWeb.ObanLive.Index
end
