defmodule UrbitEx.GroupGraph do
  alias UrbitEx.Resource

  defstruct private: false,
            members: [],
            policy: %{},
            tags: %{},
            # also the index on the graph
            url: "/ship/~mirtyl-wacdec/sample_group",
            resource: %Resource{}

  # def to_list(%{}), do: nil

  def to_list(graph) do
    _hashes =
      Map.keys(graph)
      |> Enum.map(&new(graph, &1))
  end

  def init(resource) do
    %__MODULE__{
      resource: resource,
      url: Resource.to_url(resource)
    }
  end

  def new(graph, key_string) do
    node = graph[key_string]
    ["ship", ship, name] = String.split(key_string, "/", trim: true)
    resource = Resource.new(ship, name)

    %__MODULE__{
      private: node["hidden"],
      members: node["members"],
      policy: node["policy"],
      tags: node["tags"],
      url: key_string,
      resource: resource
    }
  end

  def from_map(map, resource) do
    r = Resource.new(resource["ship"], resource["name"])
    %__MODULE__{
      private: map["hidden"],
      members: map["members"],
      policy: map["policy"],
      tags: map["tags"],
      url: Resource.to_url(r),
      resource: r
    }
  end
end
