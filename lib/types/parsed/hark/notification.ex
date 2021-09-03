defmodule UrbitEx.Notification do
  @derive Jason.Encoder

  alias UrbitEx.{Resource, Post}
  # received notifications have an "index" key, whose value is a map with a single key "graph",
  # whose value is basically the resource containing the notification,
  # and an "index" key holding "/" or the key of the post (in case of notebooks, basically)
  # follows a "notification" key whose value is the actual notification
  # notifications are a map with three keys, "contents", "read" and "time"
  defstruct type: :mention || :note || :comment || :link || :message,
            module: :chat,
            index: "/",
            group: Resource.new("mirtyl-wacdec", "group"),
            resource: nil,
            content: nil,
            read: false,
            time: DateTime.utc_now()

  def new(%{"index" => %{"graph" => _}} = wrapper) do
    module = String.split(wrapper["index"]["graph"]["mark"], "-") |> Enum.at(-1)
    type = wrapper["index"]["graph"]["description"] |> String.to_atom()

    %__MODULE__{
      type: type,
      module: String.to_atom(module),
      group: Resource.from_url(wrapper["index"]["graph"]["group"]),
      resource: Resource.from_url(wrapper["index"]["graph"]["graph"]),
      content: Enum.map(wrapper["notification"]["contents"]["graph"], &Post.new/1),
      read: wrapper["notification"]["read"],
      time: DateTime.from_unix!(wrapper["notification"]["time"], :millisecond)
    }
  end
  def new(%{"index" => %{"group" => _}} = wrapper) do

    %__MODULE__{
      type: wrapper["index"]["group"]["description"] |> String.to_atom(),
      module: :groups,
      group: Resource.from_url(wrapper["index"]["group"]["group"]),
      resource: Resource.from_url(wrapper["index"]["group"]["group"]),
      content: Enum.map(wrapper["notification"]["contents"]["group"], &groupnote/1),
      time: DateTime.from_unix!(wrapper["notification"]["time"], :millisecond)
    }
  end

  def groupnote(data) do
    [key] = Map.keys(data)
    r = data[key]["resource"]
    %{resource: Resource.new(r["ship"], r["name"]), ships: data[key]["ships"]}
  end

  def to_graph(note) do
    resource = note.resource |> Resource.to_url()
    %{resource => %{
      resource: note.resource,
      group: note.group,
      index: note.index,
      module: note.module,
      content: note.content,
      time: note.time,
      type: note.type
      }
    }
  end

  # def consolidate(list) do
    # Enum.reduce(list, %{}, fn x, acc ->
    #   proper_merge(acc, x)
    # end)
  # end

  def proper_merge(mapone, maptwo) do
    Map.merge(mapone, maptwo, fn _k, v1, v2 ->
      cond do
        is_nil(v1) -> v2
        is_list(v1) && length(v1) == 0 -> v2
        is_binary(v1) && String.length(v1) == 0 -> v2
        is_map(v1) -> proper_merge(v1, v2)
        true -> v1
      end
    end)
  end
end
