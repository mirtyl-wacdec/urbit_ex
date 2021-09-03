defmodule UrbitEx.API.Notifications do
  alias UrbitEx.{Airlock, Actions, API}
  alias UrbitEx.Timebox
  import UrbitEx.HarkStore

  @moduledoc """
  Client API to interact with `hark-store`, the notifications system of Urbit.
  """

  @doc """
  Fetches all notifications stored on your ship.
  Takes an UrbitEx.Session struct, a type atom (or string), which can be `:archive` or `:inbox`
  (for old and current notifications), an offset integer and a count integer.
  Returns a Timebox struct.
  """

  def fetch(session, type \\ :inbox, offset \\ 0, count \\ 10) do
    endpoint = "/~/scry/hark-store/recent/#{type}/#{offset}/#{count}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    {:ok, b} = Jason.decode(res.body)
    b["harkUpdate"]["more"] |> Enum.map(&Timebox.new(&1["timebox"]))
  end

  ## Specific

  @doc """
  Mark all nodes in a channel as read.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct for the group and another one for the channel.
  """

  def read_channel(session, channel, group, resource) do
    json = mark_channel_as_read(group, resource)
    body = Actions.poke(session.ship, "hark-store", "hark-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Mark a nodes *and their children* in a channel as read.
  This is used for notes and links, to set them and their children as read, together.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct for the group and another one for the channel.
  It also takes an index string of the target node and the type of channel it belongs, whether `:publish` or `:link`.
  """

  # TODO this one's tricky, it asks for "description" and "module" of the graph and the target index of the node

  def read_node(session, channel, group, resource, node_index, channel_type) do
    json = mark_node_as_read(group, resource, node_index, channel_type)
    body = Actions.poke(session.ship, "hark-store", "hark-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Mark a nodes *and their children* in a channel as read.
  This is used for notes and links, to set them and their children as read, together.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct for the group and another one for the channel.
  It also takes an index string of the target node and the type of channel it belongs, whether `:publish` or `:link`.
  """

  # TODO this one's tricky, it asks for "description" and "module" of the graph and the target index of the node

  def read_whole_node(session, channel, group, resource, node_index, channel_type) do
    json = mark_whole_node_as_read(group, resource, node_index, channel_type)
    body = Actions.poke(session.ship, "hark-store", "hark-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Ignore a channel. When ignored, your ship won't track unread nodes from that channel.
  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct for the channel.
  """

  def mute_channel(session, channel, resource) do
    json = set_channel_notifications(:ignore, resource)
    body = Actions.poke(session.ship, "hark-store", "hark-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Unmute a channel. When unmuted, your ship will track unread nodes from that channel.
  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct for the channel.
  """

  def unmute_channel(session, channel, resource) do
    json = set_channel_notifications(:listen, resource)
    body = Actions.poke(session.ship, "hark-store", "hark-action", json)
    API.wrap_put(session, channel, [body])
  end

  ## Global settings

  @doc """
  Set Do Not Disturb option. When `true`, you won't receive notifications.
  Takes an UrbitEx.Session struct and a boolean.
  """

  def do_not_disturb(session, channel, boolean) do
    json = set_dnd(boolean)
    body = Actions.poke(session.ship, "hark-store", "hark-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Set whether you want notifications when a node you authored has received replies,
  e.g. a channel you host or a notebook post you wrote.
  When `false`, you won't receive notifications.
  Takes an UrbitEx.Session struct and a boolean.
  """

  def watch_replies(session, channel, boolean) do
    json = set_watch_replies(boolean)
    body = Actions.poke(session.ship, "hark-graph-hook", "hark-graph-hook-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Set whether you want notifications when you are mentioned in a channel you are subscribed to.
  When `false`, you won't receive notifications.
  Takes an UrbitEx.Session struct and a boolean.
  """

  def watch_mentions(session, channel, boolean) do
    json = set_watch_mentions(boolean)
    body = Actions.poke(session.ship, "hark-graph-hook", "hark-graph-hook-action", json)
    API.wrap_put(session, channel, [body])
  end
end
