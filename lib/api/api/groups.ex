defmodule UrbitEx.API.Groups do
  alias UrbitEx.{API, Airlock, Actions, GraphStore, Resource, Post, Node}

  @moduledoc """
  Client API to interact with groups on Urbit .
  """

  @doc """
  Joins a public urbit group. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Joining a group, if successful, triggers 4 `group-view-update`, 1 `groupUpdate` and 1 `metadata-update`  SSE events.
  Eyre returns a 204 response.
  """
  def join_group(session, resource) do
    json = GraphStore.join_resource(resource)
    body = Actions.poke(session.ship, "group-view", "group-view-action", json)
    API.wrap_put(session, [body])
  end

  @doc """
  Leaves an Urbit group. Takes an UrbitEx.Session struct and an UrbitEx.Resoure struct.
  Leaving a group triggers 4 `metadata-update` events and one `groupUpdate` SSE event.
  Eyre returns a 200 response.
  """

  def leave_group(session, resource) do
    json = GraphStore.leave_group(resource)
    endpoint = "/spider/group-view-action/group-leave/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  # group creation and management

  @doc """
  Creates an Urbit group.
  Takes an UrbitEx.Session struct, a name string, a description string, a type string (either "open" or "invite", i.e open or private),
  an optional list of options.
  Options are banned ranks ("czar", "duke", "earl", "king", and/or "pawn"), banned ships, or invitees, for "invite" groups.
  **TODO: options don't appear to work on group creation**
  Landscape forces the name to be equal to the title (but ascii lower case, no spaces) but it can be different.
  If successful it triggers 1 `metadata-update` and 2 `groupUpdate` events.
  Eyre returns a 200 response.
  """

  def create_group(session, name, title, description, type, opts \\ []) do
    json = GraphStore.create_group(name, title, description, type, opts)
    endpoint = "/spider/group-view-action/group-create/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Deletes group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `groupUpdate` event and one `metadata-update` event.
  Eyre returns a 200 response.
  """
  def delete_group(session, resource) do
    json = GraphStore.delete_group(resource)
    endpoint = "/spider/group-view-action/group-delete/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Invite ship to an Urbit Group.
  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  a list of invitees and an invite message.
  Triggers two `group-update` events.
  Invitees will get an `invite-update` event.
  """

  def invite(session, resource, invitees, message) do
    json = GraphStore.invite_to_group(resource, invitees, message)
    endpoint = "/spider/group-view-action/group-invite/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Make a group private.   Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `groupUpdate` event. Eyre returns a 204 response.
  """
  def make_group_private(session, group), do: apply_policy_change(session, group, :to_private)

  @doc """
  Make a group private. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `groupUpdate` event. Eyre returns a 204 response.
  """
  def make_group_public(session, group), do: apply_policy_change(session, group, :to_public)

  defp apply_policy_change(session, group, policy_change) do
    json = GraphStore.change_group_policy(group, policy_change)
    body = Actions.poke(session.ship, "group-push-hook", "group-update-0", json)
    API.wrap_put(session, [body])
  end

  @doc """
  Ban ships from a group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  and a list of ships to ban. Triggers one `groupUpdate` event.
  Eyre will return a 204 even if done on a private group (where bans are nonsensical).
  """

  def ban_ships_from_group(session, group, ships), do: apply_ban(session, group, :ships, ships)

  @doc """
  Ban ranks from a group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  and a list of ranks to ban. Triggers one `groupUpdate` event.
  Eyre will return a 204 even if done on a private group (where bans are nonsensical).
  """
  def ban_ranks_from_group(session, group, ranks), do: apply_ban(session, group, :ranks, ranks)

  defp apply_ban(session, group, type, targets) do
    json = GraphStore.ban_from_group(group, type, targets)
    body = Actions.poke(session.ship, "group-push-hook", "group-update-0", json)
    API.wrap_put(session, [body])
  end

  @doc """
  Kick ships from a group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  and a list of ships to kick out. Triggers one `groupUpdate` event.
  Eyre returns a 204 even for bad grammar.
  """

  def kick_from_group(session, group, ships) when is_list(ships) do
    json = GraphStore.kick_from_group(group, ships)
    body = Actions.poke(session.ship, "group-push-hook", "group-update-0", json)
    API.wrap_put(session, [body])
  end
end
