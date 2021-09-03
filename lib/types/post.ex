defmodule UrbitEx.Post do
  @derive Jason.Encoder
  alias UrbitEx.{Utils, Post}

  defstruct index: "/170141184505084113742831691842780659712",
            author: "~mirtyl-wacdec",
            contents: [%{}],
            text: "",
            "time-sent": DateTime.utc_now(),
            signatures: [],
            hash: nil

  def new(post) when is_map(post) do
    date = post["time-sent"] |> DateTime.from_unix!(:millisecond)

    %Post{
      index: post["index"],
      author: post["author"] |> Utils.add_tilde(),
      contents: parse_contents(post["contents"]),
      text: full_text(post["contents"]),
      "time-sent": date,
      signatures: post["signatures"],
      hash: post["hash"]
    }
  end

  def new(post) when is_binary(post) do
    :deleted
  end

  defp parse_contents(contents) when is_list(contents) do
    Enum.map(contents, &parse_content/1)
  end

  # defp parse_content(%{"reference" => reference}), do: Reference.new(reference["graph"])
  defp parse_content(%{"reference" => _} = t), do: t
  # %{"code" => %{"expression" => "(add 3 2)", "output" => [["5"]]}}
  defp parse_content(%{"code" => _} = t), do: t
  defp parse_content(%{"mention" => _} = t), do: t
  defp parse_content(%{"url" => _} = t), do: t
  defp parse_content(%{"text" => _} = t), do: t

  defp full_text(contents) when is_list(contents) do
    contents
    |> Enum.filter(fn x ->
      [key] = Map.keys(x)
      key in ["text", "url", "mention"]
    end)
    |> Enum.reduce("", fn map, acc ->
      [text] = Map.values(map)
      acc <> text
    end)
  end
end
