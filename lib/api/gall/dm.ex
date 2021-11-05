defmodule UrbitEx.API.DM do
  alias UrbitEx.{API, Actions, Utils, Resource, GraphStore}
  alias UrbitEx.API.{Graph}

  @moduledoc """
  Client API to interact with `dm-hook`, new implementation of direct messaging
  Fetch, send, accept and decline DMs.
  """
  @doc """
    Fetch new DMs. Takes a Session struct, a target @p, and an optional options keyword list.
    For details check the `api/gall/graph.ex` module, DMs use the same endpoints.
  """
  def fetch_newest(session, target, opts \\ []) do
    {resource, target_ud} = set_data(session, target)
    Graph.fetch_siblings(session, resource, target_ud, :newest, opts)
  end

  def fetch_oldest(session, target, opts \\ []) do
    {resource, target_ud} = set_data(session, target)
    Graph.fetch_siblings(session, resource, target_ud, :oldest, opts)
  end

  def fetch_younger_than(session, target, index, opts \\ []) do
    {resource, target_ud} = set_data(session, target)
    Graph.fetch_siblings(session, resource, target_ud<>index, :older, opts)
  end

  def fetch_older_than(session, target, index, opts \\ []) do
    {resource, target_ud} = set_data(session, target)
    Graph.fetch_siblings(session, resource, target_ud<>index, :younger, opts)
  end

  def fetch_subset(session, target, start_index, end_index, opts \\ []) do
    {resource, target_ud} = set_data(session, target)
    Graph.fetch_subset(session, resource, target_ud<>start_index, target_ud<>end_index, opts)
  end

  def fetch_children(session, target, parent_index, start_index \\ "/", end_index \\ "/", opts \\ []) do
    {resource, target_ud} = set_data(session, target)
    Graph.fetch_children(session, resource, target_ud<>parent_index, target_ud<>start_index, target_ud<>end_index, opts)
  end

  def fetch_node(session, target, index, opts \\ []) do
    {resource, target_ud} = set_data(session, target)
    Graph.fetch_node(session, resource, target_ud<>index, opts)
  end

  defp set_data(session, target) do
    p = Utils.add_tilde(target)
    target_ud = API.evaluate(session, "`@ud`#{p}") |> String.replace(".", "")
    resource = Resource.new(session.ship, "dm-inbox")
    {resource, "/#{target_ud}"}
  end

  @doc """
  Starts a Direct Message with a ship. Takes an UrbitEx.Session struct and an Urbit @p to invite.
  """

  def send(session, channel, target, text, custom \\ nil) do
    target_num =
      API.evaluate(session, "`@ud`#{Utils.add_tilde(target)}") |> String.replace(".", "")

    json = GraphStore.send_dm(session.ship, target_num, text, custom)
    body = Actions.poke(session.ship, "dm-hook", "graph-update-3", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Accepts a Direct Message with a ship. Takes an UrbitEx.Session struct and an Urbit @p to invite.
  """
  def accept(session, channel, target) do
    json = %{accept: Utils.add_tilde(target)}
    body = Actions.poke(session.ship, "dm-hook", "dm-hook-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Declines a Direct Message with a ship. Takes an UrbitEx.Session struct and an Urbit @p to invite.
  """
  def decline(session, channel, target) do
    json = %{decline: Utils.add_tilde(target)}
    body = Actions.poke(session.ship, "dm-hook", "dm-hook-action", json)
    API.wrap_put(session, channel, [body])
  end
end
