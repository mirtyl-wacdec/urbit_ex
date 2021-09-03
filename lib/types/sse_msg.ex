defmodule UrbitEx.SSEMsg do
  @derive Jason.Encoder

  defstruct id: 0,
            data: %{}
end
