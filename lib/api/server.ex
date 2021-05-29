defmodule UrbitEx.Server do
  alias UrbitEx.{API}
  use GenServer
  require Logger

  @moduledoc """
  Main GenServer, called by the UrbitEx module. Starts a GenServer which keeps an Urbit login session as its state,
  keeping track of the Eyre channel, the actions sent and events received.
  """

  def start_link(options, name) when is_list(options) do
    GenServer.start_link(__MODULE__, options, name: name)
  end

  def start(options, name) when is_list(options) do
    GenServer.start(__MODULE__, options, name: name)
  end

  def die(name \\ :urbit_server) when is_atom(name) do
    pid = Process.whereis(name)
    Process.exit(pid, :kill)
  end

  def die(pid), do: Process.exit(pid, :kill)

  # callbacks

  @impl true
  def init(args) do
    [{:url, url}, {:code, code}] = args

    session =
      API.init(url, code)
      |> API.login()
      |> API.open_channel()
      |> API.start_sse()

    {:ok, session}
  end

  @impl true
  def handle_info(%HTTPoison.AsyncStatus{}, session) do
    {:noreply, session}
  end

  @impl true
  # ignore keep-alive messages
  def handle_info(%{chunk: "\n"}, session) do
    {:noreply, session}
  end

  @impl true
  def handle_info(%{chunk: ""}, session) do
    {:noreply, session}
  end

  @impl true
  def handle_info(%{chunk: data}, session) do
    parse_stream(data)
    {:noreply, session}
  end

  @impl true
  def handle_info({:handle_valid_message, id, message}, session) do
    broadcast(session, message)
    {events, _discarded} = Enum.split(session.recent_events, 20)
    idd = String.to_integer("#{id}")
    {:noreply, %{session | last_sse: idd, recent_events: [message | events]}}
  end

  @impl true
  def handle_info({:handle_truncated_message, id, message}, session) do
    new_session = %{session | last_sse: id, truncated_event: message}
    {:noreply, new_session}
  end

  @impl true
  def handle_info({:stack_truncated_message, message}, session) do
    tm = session.truncated_event <> message

    case Jason.decode(tm) do
      {:ok, json} ->
        send(self, {:handle_valid_message, session.last_sse, json})
        {:noreply, %{session | truncated_event: ""}}

      {:error, _r} ->
        {:noreply, %{session | truncated_event: tm}}
    end
  end

  @impl true
  def handle_info(_message, session) do
    {:noreply, session}
  end

  defp parse_stream(event) do
    rr = ~r(id:\s\d+\ndata:\s.+?}\n\n)
    messages = String.split(event, rr, include_captures: true, trim: true)

    for msg <- messages do
      check_truncated(msg)
    end
  end

  defp check_truncated(msg) do
    r = ~r(^id:\s\d+\ndata:\s)

    case Regex.match?(r, msg) do
      true ->
        [event_id, data] = String.split(msg, r, include_captures: true, trim: true)
        [id] = Regex.run(~r(\d+), event_id)
        handle_seemingly_valid(id, data)

      false ->
        handle_truncated(msg)
    end
  end

  defp handle_seemingly_valid(id, data) do
    case Jason.decode(data) do
      {:ok, json} -> send(self, {:handle_valid_message, id, json})
      {:error, _r} -> handle_truncated(id, data)
    end
  end

  # it has an id if it's the first piece of a long message
  defp handle_truncated(id, string) do
    send(self, {:handle_truncated_message, id, string})
  end

  # when it's continuing the former
  defp handle_truncated(string) do
    send(self, {:stack_truncated_message, string})
  end

  @impl true
  def handle_call(:get, _from, session) do
    {:reply, session, session}
  end

  @impl true
  def handle_cast({:subscribe, subscriptions}, session) do
    session = API.subscribe(session, subscriptions)

    session = %{session | subscriptions: [subscriptions | session.subscriptions]}
    {:noreply, session}
  end

  @impl true
  def handle_cast({:consume, pid}, session) do
    IO.inspect(pid, label: :consooming)
    {:noreply, %{session | consumers: [pid | session.consumers]}}
  end

  defp broadcast(session, message) do
    session.consumers |> Enum.each(&send(&1, message))
  end
end
