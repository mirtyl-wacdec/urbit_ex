defmodule UrbitEx.Node do
  @derive Jason.Encoder
  alias UrbitEx.{Graph, Node, Post}

  defstruct post: %Post{},
            children: nil,
            index: "/170141184505084113742831691842780659712"

  # children is a graph of children nodes, also with numbered keys, 1: 2: instead of some big index
  def new(node, index) do
    post = Post.new(node["post"])
    children = Graph.to_list(node["children"])
    %Node{post: post, children: children, index: index}
  end
end

defmodule Atomize do
  def keys_to_atoms(json) when is_map(json), do: Map.new(json, &reduce_keys_to_atoms/1)
  def keys_to_atoms(json), do: json

  def reduce_keys_to_atoms({key, val}) when is_map(val) do
    {String.to_existing_atom(key), keys_to_atoms(val)}
  end

  def reduce_keys_to_atoms({key, val}) when is_list(val) do
    {String.to_existing_atom(key), Enum.map(val, &keys_to_atoms(&1))}
  end

  def reduce_keys_to_atoms({key, val}), do: {String.to_atom(key), val}
end
