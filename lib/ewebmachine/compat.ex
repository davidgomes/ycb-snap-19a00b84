defmodule Ewebmachine.Compat do
  @moduledoc false
end

defmodule Ewebmachine.Compat.Enum do
  @moduledoc false
  
  defdelegate split_with(arg0, arg1), to: Enum
end
