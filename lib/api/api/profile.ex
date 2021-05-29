defmodule UrbitEx.API.Profile do
  alias UrbitEx.{Actions, API, Utils, ContactStore}

  def set_status(session, status) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "status", status)
    apply_change(session, json)
  end

  def update_cover(session, url) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "cover", url)
    apply_change(session, json)
  end

  def update_avatar(session, url) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "avatar", url)
    apply_change(session, json)
  end

  def update_bio(session, string) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "bio", string)
    apply_change(session, json)
  end

  def update_nickname(session, string) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "nickname", string)
    apply_change(session, json)
  end

  def update_sigil_color(session, hex_code) do
    code = String.replace_prefix(hex_code, "#", "")
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "color", code)
    apply_change(session, json)
  end

  def add_pinned_group(session, resource) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "add-group", resource)
    apply_change(session, json)
  end

  def make_profile_public(session, boolean) do
    json = %{"set-public" => boolean}
    apply_change(session, json)
  end

  defp apply_change(session, json) do
    body = Actions.poke(session.ship, "contact-store", "contact-update-0", json)
    IO.puts(Jason.encode!(body))
    API.wrap_put(session, [body]) |> IO.inspect()
  end
end
