defmodule UrbitEx.Unread do
  @derive Jason.Encoder

  alias UrbitEx.Resource
  defstruct resource: %Resource{},
            index: "/",
            last: DateTime.utc_now(),
            count: nil,
            each: nil

  def new(map) do
    [type] = map["stats"]["unreads"] |> Map.keys
    pair = [{String.to_atom(type), map["stats"]["unreads"][type]}]
    s = %UrbitEx.Unread{
      resource: Resource.from_url(map["index"]["graph"]["graph"]),
      index: map["index"]["graph"]["index"],
      last: map["stats"]["last"] |> DateTime.from_unix!(:millisecond)
    }
    struct(s, pair)
  end

  def newcount(resource, index, timestamp) do
    %__MODULE__{
      resource: resource,
      index: index,
      last: timestamp,
      count: 1
    }
  end

  def neweach(resource, index, timestamp) do
    %__MODULE__{
      resource: resource,
      index: "/",
      last: timestamp,
      each: [index]
    }
  end

end
