defmodule UrbitEx.API do
  @moduledoc """
    Module with the base functions to start the Urbit Session.
    Other complex functionality found in other files in this folder.
  """
  alias UrbitEx.{Channel, Airlock, Actions}

  @doc """
    Logs in to Urbit. Takes a url url and a code string.
    Returns an `{:ok, url, ship, cookie}` tuple if login is successful,
    or a `{:error, error}` tuple if the url or the `+code` is wrong.
  """
  def login(url, code) do
    endpoint = String.replace_suffix(url, "/", "") <> "/~/login"
    body = "password=#{code}"
    case Airlock.post(endpoint, body) do
      {:ok, res} -> login_status(res.status_code, res)
      {:error, _error} -> {:error, "Connection failed"}
    end
  end

  defp login_status(204, res) do
    {_, cookiestring} =
      Enum.find(res.headers, fn {k, _v} -> String.downcase(k) == "set-cookie" end)
    [cookie | _] = cookiestring |> String.split(";")
    # ships don't take the '~', annoyingly
    [ship] = Regex.run(~r/(?<=~)[a-z]+[^=]*/, cookie)
    url = res.request.url |> String.replace("/~/login","")
    {:ok, url, ship, cookie}
  end

  defp login_status(400, _res), do: {:error, "Wrong password"}
  defp login_status(404, _res), do: {:error, "Not an Urbit Ship Endpoint"}
  defp login_status(num, _res), do: {:error, "Error, got a #{num} status code"}


  @doc """
    Opens the Eyre channel with an empty Airlock request.
    Takes a Session struct and a Channel struct.
    Returns :ok
  """

  def open_channel(session, channel) do
    body = Actions.poke(session.ship, "hood", "helm-hi", "Opening airlock")
    wrap_put(session, channel, [body])
    :ok
  end

  @doc """
    Starts Server-side Event Evenstream, called by UrbitEx.Server on start.
    Takes a Session struct and a Channel struct.
    Returns :ok.
  """

  def start_sse(session, channel) do
    Airlock.sse(session.url, channel, session.cookie)
  end

  def restart_sse(session, channel) do
    Airlock.sse(session.url, channel, session.cookie, reconnect: true)
  end

  @doc """
    Closes an eyre channel.
    Takes a Session struct and a Channel struct.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """

  def close_channel(session, channel) do
    body = %{id: increment_id(channel, 1), action: "delete"}
    wrap_put(session, channel, [body])
  end

  @doc """
    Subscribes to Gall apps pushing events to your ship. Events will be sent to the SSE feed.
    Takes a Session struct, a Channel struct and a list of subscriptions maps.
    A subscription map takes the shape of  e.g.`%{app: "group-view", path: "/all"}`.
    See the `urbit_ex.ex` file for more examples of valid subscriptions.
    Returns a Session struct.
  """
  def subscribe(session, channel, subscriptions) when is_list(subscriptions) do
    body =
      Enum.map(subscriptions, fn sub -> Actions.subscribe(session.ship, sub.app, sub.path) end)

    wrap_put(session, channel, body)
    Enum.each(subscriptions, &Channel.save_subscription/1)
    session
  end

  @doc """
    Sends an ack to Eyre for a given event.
    Takes a Session struct, a Channel struct and an event_id, string or integer.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """

  def ack(session, channel, event_id) do
    json = Actions.ack(event_id)
    wrap_put(session, channel, [json])
  end

  @doc """
    Adds necessary metadata to `PUT` requests sent to Airlock. Keeps track of requests to increment request id
    and acks server-side events received, following Landscape practice.
    Takes a Session struct, a Channel struct and a list of request bodies for the PUT request.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """

  def wrap_put(session, channel, items) do
    body =
      items
      |> Enum.with_index()
      |> Enum.map(fn {action, index} -> Map.put(action, :id, channel.last_action + index + 1) end)

    channel = increment_id(channel, length(body))

    # body =
    #   if need_ack?(session) do
    #     Server.save_ack(channel.last_sse)
    #     [Actions.ack(channel.last_sse) | body]
    #   else
    #     body
    #   end

    Airlock.put(session.url, channel.path, session.cookie, body)
  end

  defp increment_id(channel, times) do
    Map.put(channel, :last_action, channel.last_action + times)
  end
  # TODO refine ack logic
  # defp need_ack?(channel) do
  #   channel.last_ack < channel.last_sse
  # end
  @doc """
    Fetches the last six characters of your base desk hash.
    Commonly known in Urbit as your "base hash". It shows at the bottom left corner of Landscape as of Urbit OS 2.98.
  """
  def hash(session) do
    endpoint = "/~/scry/file-server/clay/base/hash.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    {:ok, b} = Jason.decode(res.body)
    b
  end

  @doc """
    Fetches the name of the ship running at a given URL.
    Takes a url string. Returns a string with the ship name or an error tuple.
  """
  def shipname(url) do
    with {:ok, res } = HTTPoison.get(url <> "/who.json"),
         {:ok, json} = Jason.decode(res.body, keys: :atoms)
    do
      json.who
    else
      error -> error
    end
  end


  @doc """
    Evaluates Hoon code (equivalent to clicking the code button on a Landscape chat).
    Takes a Session struct and a string with hoon code.
    Returns a string with the result of the code evaluation.
  """
  def evaluate(session, code) do
    json = %{eval: code}
    endpoint = "/spider/landscape/graph-view-action/graph-eval/tang.json"
    {:ok, res} = Airlock.post(session.url <> endpoint, json, session.cookie)
    [[output]] = Jason.decode!(res.body)
    output
  end
end
