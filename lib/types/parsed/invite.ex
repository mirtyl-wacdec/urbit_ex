defmodule UrbitEx.Invite do
  alias UrbitEx.Resource

  defstruct hash: "0v6.2a08h.q8qp2.45o52.qdsdu.2qibn",
            app: "graph/group-push-hook",
            recipient: "mirtyl-wacdec",
            ship: "havsem-mirtyl-wacdec",
            text: "please com",
            resource: %Resource{}

  def to_list(%{}), do: nil

  def to_list(graph) do
    hashes =
      Map.keys(graph)
      |> Enum.map(&new(graph, &1))
  end

  def new(graph, index) do
    node = graph[index]

    %__MODULE__{
      hash: index,
      app: node["app"],
      recipient: node["recipient"],
      ship: node["ship"],
      text: node["text"],
      resource: Resource.new(node["resource"]["ship"], node["resource"]["ship"])
    }
  end
end
