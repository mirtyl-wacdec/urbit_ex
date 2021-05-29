defmodule UrbitEx.API do
  @moduledoc """
    Module with the base functions to start the Urbit Session.
    Other complex functionality found in other files in this folder.
  """
  alias UrbitEx.{Utils, Airlock, Actions, GraphStore, Resource, Post, Node}

  @doc """
    Returns an UrbitEx.Session struct, the basic data structure of Urbit session state
    kept by the UrbitEx.Server Genserver.
    Create a channel string according to Landscape convention.
  """
  def init(url, code) do
    %UrbitEx.Session{
      url: url,
      code: code,
      channel: set_channel()
    }
  end

  @doc """
  Logs in to Urbit. Takes an UrbitEx.Session struct, which includes the server url and `+code` string.
  Returns an UrbitEx.Session struct with the cookie and ship name added to it
  or raises an error if the `code` is wrong.
  """
  def login(session) do
    endpoint = "/~/login"
    url = session.url <> endpoint
    body = "password=#{session.code}"
    {:ok, res} = Airlock.post(url, body)
    login_status(session, res.status_code, res)
  end

  defp login_status(session, 204, res) do
    {_, cookiestring} = Enum.find(res.headers, fn x -> match?({"set-cookie", _}, x) end)
    [cookie | _] = cookiestring |> String.split(";")
    # ships don't take the '~', annoyingly
    [ship] = Regex.run(~r/(?<=~)[a-z]+[^=]*/, cookie)

    session
    |> Map.put(:cookie, cookie)
    |> Map.put(:ship, ship)
    # don't need to keep it there
    |> Map.put(:code, :logged_in)
  end

  defp login_status(_session, 400, res), do: raise("Wrong password")

  defp set_channel do
    "/~/channel/#{System.os_time(:millisecond)}-#{:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)}"
  end

  @doc """
    Opens the Eyre channel with an empty Airlock request. Takes an UrbitEx.Session struct.
    called by UrbitEx.Server on start.
  """

  def open_channel(session) do
    body = Actions.poke(session.ship, "hood", "helm-hi", "Opening airlock")
    wrap_put(session, [body])
    session
  end

  @doc """
    Starts Server-side Event Evenstream, called by UrbitEx.Server on start. Takes an UrbitEx.Session struct.
    Pass a receive loop to the process receiving Event messages to handle them in your program.
  """

  def start_sse(session) do
    {:ok, _res} = Airlock.sse(session.url, session.channel, session.cookie, session.last_sse)
    session
  end

  @doc """
    Logs out of your Urbit session and kills the GenServer keeping the state.
    Takes an UrbitEx.Session struct.
  """

  def logout(session) do
    body = %{id: increment_id(session, 1), action: "delete"}
    wrap_put(session, [body])
    session
    UrbitEx.Server.die()
  end

  @doc """
    Subscribes to Gall apps pushing events to your ship. Events will be sent to the SSE feed.
  """
  def subscribe(session, subscriptions) when is_list(subscriptions) do
    body =
      Enum.map(subscriptions, fn sub -> Actions.subscribe(session.ship, sub.app, sub.path) end)

    wrap_put(session, body)
    session
  end

  @doc """
    Adds necessary metadata to `PUT` requests sent to Airlock. Keeps track of requests to increment request id
    and acks server-side events received, following Landscape practice.
     Takes an UrbitEx.Session struct and a list of request bodies for the PUT request.
  """

  def wrap_put(session, items) do
    body =
      items
      |> Enum.with_index()
      |> Enum.map(fn {action, index} -> Map.put(action, :id, session.last_action + index + 1) end)

    session = increment_id(session, length(body))

    body = if need_ack?(session), do: [Actions.ack(session.last_sse) | body], else: body
    Airlock.put(session.url, session.channel, session.cookie, body)
  end

  defp increment_id(session, times) do
    Map.put(session, :last_action, session.last_action + times)
  end

  defp need_ack?(session) do
    session.last_ack < session.last_sse
  end
end
