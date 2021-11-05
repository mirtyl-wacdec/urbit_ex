defmodule UrbitEx.API.Groups do
  alias UrbitEx.{API, Airlock, Actions, GraphStore, GroupStore}

  @moduledoc """
  Client API to interact with groups on Urbit.
  Create groups, delete them, join others, all interactions with groups is here.
  """

  @doc """
  Joins a public urbit group.
  Takes a Session struct, a Channel struct and a Resource struct of the group to join.
  Joining a group, if successful, triggers 4 `group-view-update`, 1 `groupUpdate` and 1 `metadata-update`  SSE events.
  Eyre returns a 204 response.
  """
  def join(session, channel, resource) do
    json = GraphStore.join_resource(resource)
    body = Actions.poke(session.ship, "group-view", "group-view-action", json)
    API.wrap_put(session, channel, [body])
  end

  def await_join(group) do
    receive do
      {:join_group_requested, ^group} ->
        await_join(group)

      {:join_group_started, ^group} ->
        await_join(group)

      {:join_group_progress, ^group, "no-perms"} ->
        :no_perms

      {:join_group_progress, ^group, "done"} ->
        :ok

      {:join_group_progress, ^group, _progress} ->
        await_join(group)

      _ ->
        :error
    end
  end

  @doc """
    Dismisses a pending or completed group join (those remain and are displayed as notifications on startup if not dismissed).
    Takes a Session struct, a Channel struct and a Resource struct.
  """

  def dismiss_join(session, channel, resource) do
    json = GroupStore.cancel_join(resource)
    body = Actions.poke(session.ship, "group-view", "group-view-action", json)
    API.wrap_put(session, channel, [body])
  end
  @doc """
    Alias of `dismiss_join/3`
  """
  def cancel_join(s, c, r), do: dismiss_join(s, c, r)

  @doc """
  Leaves an Urbit group. Takes an UrbitEx.Session struct and an UrbitEx.Resoure struct.
  Leaving a group triggers 4 `metadata-update` events and one `groupUpdate` SSE event.
  Eyre returns a 200 response.
  """

  def leave(session, resource) do
    json = GroupStore.leave(resource)
    endpoint = "/spider/landscape/group-view-action/group-leave/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  # group creation and management

  @doc """
  Creates an Urbit group.
  Takes an UrbitEx.Session struct, a name string, a description string, a type string (either "open" or "invite", i.e open or private),
  an optional keyword list of options.
  Option keys are `:banned_ranks` ("czar", "duke", "earl", "king", and/or "pawn"), `:banned_ships`, or `:invitees`, for "invite" groups. All values must be lists of valid @ps.
  Landscape forces the name to be equal to the title (but ascii lower case, no spaces) but it can be different.
  If successful it triggers 1 `metadata-update` and 2 `groupUpdate` events.
  Eyre returns a 200 response.
  """


  def create(session, name, title, description, type, opts \\ []) do
    json = GroupStore.create(name, title, description, type, opts)
    endpoint = "/spider/landscape/group-view-action/group-create/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  def await_create(group) do
    receive do
      {:add_group, ^group} -> {:ok, :group_created}
    after
      5000 -> {:error, :error_creating_group}
    end
  end

  @doc """
  Deletes group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `groupUpdate` event and one `metadata-update` event.
  Eyre returns a 200 response.
  """
  def delete(session, resource) do
    json = GroupStore.delete(resource)
    endpoint = "/spider/landscape/group-view-action/group-delete/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Invite ship to an Urbit Group.
  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  a list of invitees and an invite message string.
  Triggers two `group-update` events.
  Invitees will get an `invite-update` event.
  """

  def invite(session, resource, invitees, message) do
    json = GroupStore.invite(resource, invitees, message)
    endpoint = "/spider/landscape/group-view-action/group-invite/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Make a group private.   Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `groupUpdate` event. Eyre returns a 204 response.
  """
  def make_private(session, channel, group),
    do: apply_policy_change(session, channel, group, :to_private)

  @doc """
  Make a group private. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `groupUpdate` event. Eyre returns a 204 response.
  """
  def make_public(session, channel, group),
    do: apply_policy_change(session, channel, group, :to_public)

  defp apply_policy_change(session, channel, group, policy_change) do
    json = GroupStore.change_policy(group, policy_change)
    body = Actions.poke(session.ship, "group-push-hook", "group-update-0", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Ban ships from a group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  and a list of ships to ban. Triggers one `groupUpdate` event.
  Eyre will return a 204 even if done on a private group (where bans are nonsensical).
  """

  def ban_ships(session, channel, group, ships),
    do: apply_ban(session, channel, group, :ships, ships)

  @doc """
  Ban ranks from a group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  and a list of ranks to ban.
  Ranks are "czar", "duke", "earl", "king", and/or "pawn", in order.
  Triggers one `groupUpdate` event.
  Eyre will return a 204 even if done on a private group (where bans are nonsensical).
  """
  def ban_ranks(session, channel, group, ranks),
    do: apply_ban(session, channel, group, :ranks, ranks)

  defp apply_ban(session, channel, group, type, targets) do
    json = GroupStore.ban(group, type, targets)
    body = Actions.poke(session.ship, "group-push-hook", "group-update-0", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Kick ships from a group.  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct,
  and a list of ships to kick out. Triggers one `groupUpdate` event.
  Eyre returns a 204 even for bad grammar.
  """

  def kick(session, channel, group, ships) when is_list(ships) do
    json = GroupStore.kick(group, ships)
    body = Actions.poke(session.ship, "group-push-hook", "group-update-0", json)
    API.wrap_put(session, channel, [body])
  end

  # def fetch(session, keyword) do
  #   endpoint = "/~/scry/group-store/#{keyword}.json"
  #   {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
  #   res.body
  #   # {:ok, b} = Jason.decode(res.body)
  # end

end
