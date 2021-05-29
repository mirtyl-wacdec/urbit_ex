defmodule UrbitEx.Node do
  @derive Jason.Encoder
  alias UrbitEx.{Graph, Node, Post}

  defstruct post: %Post{},
            children: nil

  # children is a graph of children nodes, also with numbered keys, 1: 2: instead of some big index
  def new(node) do
    post = Post.new(node["post"])
    children = Graph.to_list(node["children"])
    %Node{post: post, children: children}
  end
end
