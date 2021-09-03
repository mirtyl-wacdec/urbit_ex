defmodule UrbitEx.InviteStore do
  def accept_invite(type, invite_id), do: %{accept: %{term: type, uid: invite_id}}

  def decline_invite(type, invite_id), do: %{decline: %{term: type, uid: invite_id}}
end
