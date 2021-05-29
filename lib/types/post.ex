defmodule UrbitEx.Post do
  @derive Jason.Encoder
  alias UrbitEx.{Utils, Graph, Node, Post}

  defstruct index: 0,
            author: "~mirtyl-wacdec",
            contents: [%{}],
            "time-sent": 0,
            signatures: [],
            hash: nil

  def new(post) when is_map(post) do
    %Post{
      index: post["index"],
      author: post["author"] |> Utils.add_tilde(),
      contents: post["contents"],
      "time-sent": post["time-sent"],
      signatures: post["signatures"],
      hash: post["hash"]
    }
  end

  def new(post) when is_binary(post) do
    :deleted
  end
end
