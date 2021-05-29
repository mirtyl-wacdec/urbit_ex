defmodule UrbitEx.GroupGraph do
  alias UrbitEx.Resource
  # "/ship/~mirtyl-wacdec/apitest2" => %{
  #   "hidden" => false,
  #   "members" => ["havsem-mirtyl-wacdec", "timlet-barlep-docteg-mothep",
  #    "mirtyl-wacdec"],
  #   "policy" => %{"open" => %{"banRanks" => [], "banned" => []}},
  #   "tags" => %{"admin" => ["mirtyl-wacdec"]}
  # }

  defstruct private: false,
            members: ["mirtyl-wacdec", "zod"],
            policy: %{},
            tags: %{},
            # also the index on the graph
            url: "/ship/~mirtyl-wacdec/apitest2",
            resource: %Resource{}

  # def to_list(%{}), do: nil

  def to_list(graph) do
    hashes =
      Map.keys(graph)
      |> Enum.map(&new(graph, &1))
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
end
