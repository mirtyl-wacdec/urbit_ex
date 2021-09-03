defmodule UrbitEx.API.Profile do
  @moduledoc """
    Client API to interact with the `contacts-store` of your Urbit Ship.
    Includes functions to change your Urbit profile.
  """
  alias UrbitEx.{Actions, API, Utils, ContactStore}
  @doc """
    Sets your public status.
    Takes a Session struct, a Channel struct, and the string to apply.
  """
  def set_status(session, channel, status) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "status", status)
    apply_change(session, channel, json)
  end
  @doc """
    Sets your cover picture.
    Takes a Session struct, a Channel struct, and a url string to apply.
  """
  def update_cover(session, channel, url) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "cover", url)
    apply_change(session, channel, json)
  end

  @doc """
    Sets your avatar picture.
    Takes a Session struct, a Channel struct, and a url string to apply.
  """
  def update_avatar(session, channel, url) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "avatar", url)
    apply_change(session, channel, json)
  end

  @doc """
    Sets your public bio.
    Takes a Session struct, a Channel struct, and the string to apply.
  """
  def update_bio(session, channel, string) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "bio", string)
    apply_change(session, channel, json)
  end

  @doc """
    Sets your public nickname.
    Takes a Session struct, a Channel struct, and the string to apply.
  """
  def update_nickname(session, channel, string) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "nickname", string)
    apply_change(session, channel, json)
  end

  @doc """
    Sets your sigil color.
    Takes a Session struct, a Channel struct, and the color hex code string to apply.
  """
  def update_sigil_color(session, channel, hex_code) do
    code = String.replace_prefix(hex_code, "#", "")
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "color", code)
    apply_change(session, channel, json)
  end

  @doc """
    Adds a pinned group to your public profile.
    Takes a Session struct, a Channel struct, and a Resource struct of the group to apply.
  """
  def add_pinned_group(session, channel, resource) do
    json = ContactStore.edit_field(Utils.add_tilde(session.ship), "add-group", resource)
    apply_change(session, channel, json)
  end

  @doc """
    Sets your public as public or private.
    Takes a Session struct, a Channel struct, and a boolean, true for public.
  """
  def make_profile_public(session, channel, boolean) do
    json = %{"set-public" => boolean}
    apply_change(session, channel, json)
  end

  defp apply_change(session, channel, json) do
    body = Actions.poke(session.ship, "contact-store", "contact-update-0", json)
    IO.puts(Jason.encode!(body))
    API.wrap_put(session, channel, [body])
  end
end
