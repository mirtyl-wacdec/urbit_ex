defmodule UrbitEx.API.Settings do
  import UrbitEx.SettingsStore
  alias UrbitEx.{Actions, API, Airlock}

  @moduledoc """
  Client API to interact with settings on Urbit.
  Urbit `settings-store` is a simple key-value store with a simple API.
  There's "buckets" and "entries". Entries have a value which can be an integer, a string or a list.
  Landscape has its own set of settings (background images, whether to show nicknames or render avatars, etc.)
  But you can store anything you want in there.
  This module provides functions to modify Landscape settings as well as insert or delete your own.
  This module also includes functions to interact with `s3-store`, the module to set up S3 buckets.
  `s3-store` precedede `settings-store` but it might be merged into it in the future.
  """

  defp return(data) do
    case Jason.decode(data) do
      {:ok, json} ->
         [key] = Map.keys(json)
         {:ok, json[key]}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Fetches all settings in your ship's `settings-store`.
  Takes an UrbitEx.Session struct.
  """

  def fetch_all(session) do
    endpoint = "/~/scry/settings-store/all.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    return(res.body)
  end

  @doc """
  Fetches the value of a given bucket in your `settings-store`.
  Takes an UrbitEx.Session struct and a bucket string.
  """
  def fetch_desk(session, desk) do
    endpoint = "/~/scry/settings-store/desk/#{desk}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    return(res.body)
  end
  def fetch_bucket(session, desk, bucket) do
    endpoint = "/~/scry/settings-store/bucket/#{desk}/#{bucket}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    return(res.body)
  end

  @doc """
  Fetches the value of a given entry of a given bucket in your `settings-store`.
  Takes an UrbitEx.Session struct, a bucket string and an entry string.
  """

  def fetch_entry(session, desk, bucket, entry) do
    endpoint = "/~/scry/settings-store/entry/#{desk}/#{bucket}/#{entry}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    return(res.body)
  end

  @doc """
  Queries your `settings-store` to see if a given bucket exists.
  Returns a boolean.
  Takes an UrbitEx.Session struct and a bucket string.
  """

  def has_bucket?(session, bucket) do
    endpoint = "/~/scry/settings-store/has-bucket/#{bucket}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    UrbitEx.Utils.eyre_boolean?(res.status_code)
  end

  @doc """
  Queries your `settings-store` to see if a given entry of a given bucket exists.
  Returns a boolean.
  Takes an UrbitEx.Session struct, a bucket string and an entry string.
  """

  def has_entry?(session, bucket, entry) do
    endpoint = "/~/scry/settings-store/has-entry/#{bucket}/#{entry}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    UrbitEx.Utils.eyre_boolean?(res.status_code)
  end

  ## LANDSCAPE SETTINGS

  defp apply_changes(session, channel, json) do
    body = Actions.poke(session.ship, "settings-store", "settings-event", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Set to hide or not hide nicknames on Landscape.
  Takes an UrbitEx. Session struct and a boolean.
  """

  def hide_nicknames(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :hideNicknames, boolean))

  @doc """
  Set to hide or not hide avatars on Landscape.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def hide_avatars(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :hideAvatars, boolean))

  @doc """
  Set to hide or not hide the counts of unread messages per group on Landscape.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def hide_unreads(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :hideUnreads, boolean))

  @doc """
  Set to hide or not hide the utlity tiles (Weather, Clock, etc.) on Landscape.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def hide_utilities(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :hideUtilities, boolean))

  @doc """
  Set to hide or not hide the group tiles on Landscape. If you really really like the weather and clock tiles.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def hide_groups(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :hideGroups, boolean))

  @doc """
  Set to toggle whether to render images automatically on Landscape.
  If set to `false` only urls will render. This and the following settings are useful
  in order to avoid your browser IP address to leak to the server of the remote content.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def render_images(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :imageShown, boolean))

  @doc """
  Set whether to render a media player for audio on Landscape.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def play_audio(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :audioShown, boolean))

  @doc """
  Set whether to render a media player for video on Landscape.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def play_video(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :videoShown, boolean))

  @doc """
  Set whether to render embedded content (Twitter links and other OEmbed content) on Landscape.
  Takes an UrbitEx. Session struct and a boolean.
  """
  def render_embeds(session, channel, boolean),
    do: apply_changes(session, channel, put_entry(:landscape, :calm, :oembedShown, boolean))

  @doc """
  Sets the Landscape theme. Takes an UrbitEx.Session struct and a theme string.
  Default theme is light, unless "dark" is specified.
  """
  def theme(session, channel, theme),
    do: apply_changes(session, channel, put_entry(:landscape, :display, :theme, theme))

  @doc """
  Sets the Landscape background image. Takes an UrbitEx.Session struct and a url string.
  """

  def set_background_image(session, channel, url) do
    json = put_entry(:landscape, :display, :backgroundType, :url)
    apply_changes(session, channel, json)
    json2 = put_entry(:landscape, :display, :background, url)
    apply_changes(session, channel, json2)
  end

  @doc """
  Sets the Landscape background color. Takes an UrbitEx.Session struct and a color string.
  Color can be any css color string, Landscape appears to read it as is.
  """
  def set_background_color(session, channel, color) do
    json = put_entry(:landscape, :display, :backgroundType, :color)
    apply_changes(session, channel, json)
    json2 = put_entry(:landscape, :display, :background, color)
    apply_changes(session, channel, json2)
  end

  @doc """
  Removes custo background. Takes an UrbitEx.Session struct.
  """

  def remove_background(session, channel),
    do: apply_changes(session, channel, put_entry(:landscape, :display, :backgroundType, :none))

  @doc """
  Adds your own category of setting to your Urbit settings-store.
  Takes an UrbitEx.Session struct and a name string for the "bucket". Can be anything.
  """
  ## TODO can't have whitespace in the names!! entries too!
  ## I mean you can set them up with whitespace but then they bugout on scrying
  def add_custom_bucket(session, channel, desk, bucket),
    do: apply_changes(session, channel, put_bucket(desk, bucket))

  @doc """
  Add your own setting to your Urbit settings-store under a given bucket.
  Takes an UrbitEx.Session struct, an entry string and a value.
  Values can be integers, strings or lists (of integers or strings).
  The setting stays there so you can read it later at your convenience and use it however you want.
  """

  def add_custom_entry(session, channel, desk, bucket, entry, value),
    do: apply_changes(session, channel, put_entry(desk, bucket, entry, value))

  @doc """
  Delete settings bucket. Takes an UrbitEx.Session struct, and a string for the bucket name you want to delete.
  """

  def remove_bucket(session, channel, desk, bucket),
    do: apply_changes(session, channel, del_bucket(desk, bucket))

  @doc """
  Delete settings entry. Takes an UrbitEx.Session struct,
  a string for the bucket, and a string for the entry you want to delete.
  """
  def remove_entry(session, channel, desk, bucket, entry),
    do: apply_changes(session, channel, del_entry(desk, bucket, entry))

  ## S3
  @doc """
  Fetches the current configuration of the S3 server.
  Takes an UrbitEx.Session struct.
  """
  def fetch_s3_configuration(session) do
    endpoint = "/~/scry/s3-store/configuration.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    {:ok, b} = Jason.decode(res.body)
    b["s3-update"]
  end

  @doc """
  Fetches the current credentials of the S3 server.
  Takes an UrbitEx.Session struct.
  """

  def fetch_s3_credentials(session) do
    endpoint = "/~/scry/s3-store/credentials.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    {:ok, b} = Jason.decode(res.body)
    b["s3-update"]
  end

  defp apply_s3(session, channel, json) do
    body = Actions.poke(session.ship, "s3-store", "s3-action", json)
    API.wrap_put(session, channel, [body])
  end

  @doc """
  Set the URL hosting your S3 server. Takes an UrbitEx.Session struct and an string for the endpoint.
  """
  def set_s3_endpoint(session, channel, endpoint),
    do: apply_s3(session, channel, s3("set-endpoint", endpoint))

  @doc """
  Set the access key (the login) of your S3 server.
  Takes an UrbitEx.Session struct and an string for the access key.
  """
  def set_s3_access_key(session, channel, login),
    do: apply_s3(session, channel, s3("set-access-key-id", login))

  @doc """
  Set the secret key (the password) of your S3 server.
  Takes an UrbitEx.Session struct and an string for the password.
  """

  def set_s3_secret(session, channel, password),
    do: apply_s3(session, channel, s3("set-secret-access-key", password))

  @doc """
  Add a bucket from your S3 server. Takes an UrbitEx.Session struct and an string for the bucket name.
  """
  def add_s3_bucket(session, channel, name),
    do: apply_s3(session, channel, s3("add-bucket", name))

  @doc """
  Remove an S3 bucket. Takes an UrbitEx.Session struct and an string for the bucket name.
  """
  def remove_s3_bucket(session, channel, name),
    do: apply_s3(session, channel, s3("remove-bucket", name))

  @doc """
  Set the default bucket to use for Urbit. Takes an UrbitEx.Session struct and an string for the bucket name.
  """
  def set_default_s3_bucket(session, channel, name),
    do: apply_s3(session, channel, s3("set-current-bucket", name))
end
