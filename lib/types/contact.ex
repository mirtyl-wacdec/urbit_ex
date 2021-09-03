defmodule UrbitEx.Contact do
  alias UrbitEx.Resource
  @derive Jason.Encoder

  defstruct p: "~sampel-palnet",
            avatar: nil,
            bio: "",
            color: "0x0",
            cover: "",
            groups: [],
            last_updated: 1_616_869_406_838,
            nickname: nil,
            status: "welcome to mars"

  def to_list(graph) do
    graph
    |> Map.keys()
    |> Enum.map(&new(&1, graph[&1]))
  end

  def new(p, nil) do
    struct(__MODULE__, %{p: p})
  end

  def new(p, map) do
    %__MODULE__{
      p: p,
      avatar: map["avatar"],
      bio: map["bio"],
      color: map["color"],
      cover: map["cover"],
      groups: map["groups"] |> Enum.map(&Resource.from_url/1),
      last_updated: map["last-updated"],
      nickname: map["nickname"],
      status: map["status"]
    }
  end
end

# edited a bunch of things, got an event per each as:
# %{
#   "edit" => %{
#     "edit-field" => %{
#       "avatar" => "https://i1.sndcdn.com/artworks-000267560042-rxom3p-t500x500.jpg"
#     },
#     "ship" => "daclug-misryc-sibbyr-sictyl--riddyt-socted-fitret-litzod",
#     "timestamp" => 1622922761320
#   }
# }

# %{"set-public" => true}
