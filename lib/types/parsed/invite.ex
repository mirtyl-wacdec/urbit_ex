defmodule UrbitEx.Invite do
  alias UrbitEx.{Resource, Utils}

  defstruct hash: "0v6.2a08h.q8qp2.45o52.qdsdu.2qibn",
            term: "graph or group",
            recipient: "~mirtyl-wacdec",
            ship: "~havsem-mirtyl-wacdec",
            text: "please come",
            resource: %Resource{}

  def to_list(nil, _term), do: []
  def to_list(graph, _term) when graph == %{}, do: []

  def to_list(graph, term) do
    _hashes =
      Map.keys(graph)
      |> Enum.map(&new(graph, &1, term))
  end

  def test(%{}), do: :empty
  def test(graph), do: Map.keys(graph)

  def new(graph, index, term) do
    node = graph[index]

    %__MODULE__{
      hash: index,
      term: term,
      recipient: node["recipient"] |> Utils.add_tilde(),
      ship: node["ship"] |> Utils.add_tilde(),
      text: node["text"],
      resource: Resource.new(node["resource"]["ship"], node["resource"]["name"])
    }
  end

  def new_incoming(invite) do
    node = invite["invite"]

    %__MODULE__{
      hash: invite["uid"],
      term: invite["term"],
      recipient: node["recipient"] |> Utils.add_tilde(),
      ship: node["ship"] |> Utils.add_tilde(),
      text: node["text"],
      resource: Resource.new(node["resource"]["ship"], node["resource"]["name"])
    }
  end
end
