defmodule UrbitEx.Metadata do
  alias UrbitEx.{Utils, Resource}
  @derive Jason.Encoder


  # metadata got from the "metadata-store"
  # TODO
  # and from "metadata-pull-hook" are somewhat different
  # the latter has a preview, then includes "channel-count" and "channels" key.
  # channels are the pinned ones

  defstruct color: "000000",
            creator: "~zod",
            group: Resource.new("mirtyl-wacdec", "oh-hai"),
            resource: Resource.new("mirtyl-wacdec", "oh-hai-3201"),
            private: true,
            created_at: Utils.da_to_date("~2021.4.29..11.14.46..91d8"),
            description: "",
            picture: "",
            preview: false,
            title: "Channel Title",
            permissions: "reader-comments",
            feed: nil,
            app: :graph

  def to_list(nil), do: []

  def to_list(graph) do
    Map.keys(graph)
    |> Enum.map(&graph[&1])
    |> Enum.map(&new/1)
  end

  def process(graph) do
    graph
    |> Enum.map(fn {k, v} -> {k, new(v)} end)
    |> Enum.into(%{})
  end

  def new(map) do
    app = (map["metadata"]["config"]["graph"] || map["app-name"]) |> String.to_atom()

    feed =
      if app == :groups,
        do: Resource.from_url(map["metadata"]["config"]["group"]["resource"]),
        else: nil

    %__MODULE__{
      group: map["group"] |> Resource.from_url(),
      app: app,
      feed: feed,
      creator: map["metadata"]["creator"],
      private: map["metadata"]["hidden"],
      resource: Resource.from_url(map["resource"]),
      title: map["metadata"]["title"],
      description: map["metadata"]["description"],
      created_at: map["metadata"]["date-created"] |> Utils.da_to_date(),
      color: map["metadata"]["color"],
      picture: map["metadata"]["picture"],
      permissions: map["metadata"]["vip"]
    }
  end

  def own(session) do
    session.metadata
    |> Enum.filter(&(&1.creator == Utils.add_tilde(session.ship)))
  end

  def channels(session) do
    session.metadata
    |> Enum.filter(&(&1.group == &1.resource && &1.app != :groups))
  end

  def groups(session) do
    session.metadata
    |> Enum.filter(&(&1.app == :groups))
  end
end
