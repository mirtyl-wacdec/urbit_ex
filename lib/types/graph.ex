defmodule UrbitEx.Graph do
  alias UrbitEx.{Graph, Node, Post}

  def new(graph) do
    # :gb_trees !!
  end

  def to_list(nil), do: nil

  def to_list(graph) do
    Map.keys(graph)
    |> Enum.map(&graph[&1])
    |> Enum.map(&Node.new/1)
  end
end
