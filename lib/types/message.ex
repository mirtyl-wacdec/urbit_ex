defmodule UrbitEx.Message do
  defstruct resource: %{},
            index: 0,
            author: "",
            contents: [%{}],
            timestamp: 0,
            signatures: [],
            hash: nil,
            children: nil
end
