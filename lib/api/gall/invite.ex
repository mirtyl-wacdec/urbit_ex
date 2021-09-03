defmodule UrbitEx.API.Invite do
  import UrbitEx.InviteStore
  alias UrbitEx.{API, Actions}

  @moduledoc """
    Client API to interact with `invite-store` on Urbit.
    Includes functions to accept and invite declines.
    Sending of invites depends of `group-store` or `graph-store`.
  """

  def f(session, uid) do
    endpoint = "/~/scry/invite-store/groups/#{uid}.json"
    {:ok, _res} = UrbitEx.Airlock.get(session.url <> endpoint, session.cookie)
    # {:ok, b} = Jason.decode(res.body)
  end

  def accept(session, channel, invite) do
    json = accept_invite(invite.term, invite.hash)
    body = Actions.poke(session.ship, "invite-store", "invite-action", json)
    API.wrap_put(session, channel, [body])
    join(session, channel, invite.resource)
  end

  defp join(session, channel, resource) do
    json = UrbitEx.GraphStore.join_resource(resource)
    body = Actions.poke(session.ship, "group-view", "group-view-action", json)
    API.wrap_put(session, channel, [body])
  end

  # TODO takes two attempts to actually decline, first one returns a 400 "bad channel json"

  def decline(session, channel, invite) do
    json = decline_invite(invite.term, invite.hash)
    body = Actions.poke(session.ship, "invite-store", "invite-action", json)
    API.wrap_put(session, channel, [body])
  end
end
