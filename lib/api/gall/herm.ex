defmodule UrbitEx.Terminal do
  alias UrbitEx.{Utils, API, Actions}
  ## error messages in dojo can be accessed through a completely separate SSE pipeline
  ## at GET "/~_~/slog"
  ## which inputs plaintext errors

  @moduledoc """
    Module with functions to interact with `herm`, the Urbit virtual terminal.
    Subscription to herm will trigger an SSE pipeline outputting the return of every statement.
    Error messages are not shown in that channel, instead there is a separate SSE pipeline called `slog`.
    You can access that by running the `slog/1` function.
  """

  @doc """
    Subscribes to `herm` in order to receive SSE events from it.
    Takes a Session struct and a Channel struct.
    Returns `:ok`
  """

  def subscribe(session, channel) do
    sub = %{app: "herm", path: "/session/"}
    API.subscribe(session, channel, [sub])
    :ok
  end

  @doc """
    Opens a SSE pipeline to receive unprompted Terminal logs and error messages.
  """

  def slog(session) do
    headers = %{
      "Connection" => "keep-alive",
      "Accept" => "text/event-stream",
      "Cookie" => session.cookie,
      "Cache-Control" => "no-cache",
      "User-Agent" => "UrbitEx"
    }
    sse_options = [stream_to: self(), recv_timeout: :infinity]
    HTTPoison.get(session.url<>"/~_~/slog", headers, sse_options)
  end

  @doc """
    Sends a string to the terminal.
    Note this only types the string in, it does not enter the command.
    Takes a Session Struct, a Channel struct and the string to send.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """
  def send_string(session, channel, string), do: poke(session, channel, %{txt: [string]})
 @doc """
    Send a backspace to the terminal.
    Takes a Session Struct and a Channel struct.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """
  def backspace(session, channel), do: poke(session, channel, %{bac: nil})
   @doc """
    Send a delete keystroke (deleting the key next to the cursor) to the terminal.
    Takes a Session Struct and a Channel struct.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """
  def delete(session, channel), do: poke(session, channel, %{del: nil})
   @doc """
    Send an enter key stroke to the terminal, running the command in the prompt.
    Takes a Session Struct and a Channel struct.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """
  def return(session, channel), do: poke(session, channel, %{ret: nil})
  @doc """
    Send an arrow keystroke to the terminal.
    Takes a Session Struct, a Channel struct and the arrow to send, in atom form (`:up`, `:down`, `:left` or `:right`)
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """
  def arrow(session, channel, arrow) do
    aro =
      case arrow do
        :up -> "u"
        :down -> "d"
        :left -> "l"
        :right -> "r"
      end

    poke(session, channel, %{aro: aro})
  end

  @doc """
    Send an keystroke with the "control" key pressed, to the terminal.
    Takes a Session Struct, a Channel struct and the key to send.
    For what it's worth, a tab is equivalent to CTRL+ "i". It gives a lists of functions in the hoon standard library.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """
  def mod(session, channel, modifier) do
    # tab is "i"
    poke(session, channel, %{ctl: modifier})
  end

  @doc """
    Sends a `|hi` to an Urbit ship. Useful command to troubleshoot network connections (akin to ping in Unix).
    Takes a Session Struct, a Channel struct and the Urbit @p to ping.
    Returns an {:ok, %HTTPoison.Response{}} tuple.
  """
  def hi(session, channel, target) do
    patp = Utils.add_tilde(target)
    send_string(session, channel, "|hi #{patp}")
    return(session, channel)
  end

  defp poke(session, channel, json) do
    body = Actions.poke(session.ship, "herm", "belt", json)
    API.wrap_put(session, channel, [body])
  end
end
