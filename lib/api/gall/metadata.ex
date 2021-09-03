defmodule UrbitEx.API.Metadata do
  @moduledoc """
    Client API to interact with the `metadata-store` of your Urbit ship.
    Allows you to change the metadata of groups and channels you own or are admin of, as well as preview metadata of groups you don't belong to yet.
  """
  alias UrbitEx.{MetadataStore, API, Actions, Resource}


  def preview(session, channel, resource) do
    body =
      Actions.subscribe(
        session.ship,
        "metadata-pull-hook",
        "/preview#{Resource.to_url(resource)}"
      )

    API.wrap_put(session, channel, [body])
  end

  def await_preview() do
    receive do
      {:group_preview, preview} ->
        preview

      {:error, _error} ->
        :no_group
    end
  end

  @doc """
    Edits the Metadata of a group or channel.
    Takes a Session struct, a Channel struct, a group Resource struct, a channel Resource struct,
    a type (either `:groups` or `:graph`), the key to edit, and the value to set.
    Keys can be:
    - `title` takes a string
    - `description` takes a string
    - `color` takes a hex code string
    - `picture` takes a url string
    - `vip` applied to a group:  "member-metadata" or ""
    - `vip` applied to a group-feed : "host-feed" or "admin-feed" or ""
    - `vip` applied to a notebook: "reader-comments" or ""
    - `preview` true or false
  """
  def edit(session, channel, group, resource, type, key, value) do
    json = MetadataStore.edit(group, resource, type, key, value)
    body = Actions.poke(session.ship, "metadata-push-hook", "metadata-update-2", json)
    API.wrap_put(session, channel, [body])
  end

end
