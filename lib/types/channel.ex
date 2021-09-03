defmodule UrbitEx.Channel do
   @moduledoc """
    GenServer module to open Eyre channels.
    Defines an UrbitEx.Channel struct to keep track of the channel state.
    Elixir processes can subscribe to channels to consume the events their propagate, either raw Eyre events or Eyre events parsed by UrbitEx.Reducer
  """

  alias UrbitEx.{Session, API}
  @derive Jason.Encoder
  use GenServer

  defstruct name: :main,
            path: "/~/channel/1624121301252-9e6659",
            parent: :pid,
            last_action: 0,
            last_sse: 0,
            last_ack: 0,
            recent_events: [],
            subscriptions: [],
            truncated_event: "",
            consumers: [],
            raw_consumers: [],
            status: :init,
            autoack: false,
            last_event: Time.utc_now(),
            keep_state: true


  @doc """
    Fetches Channel state. Takes a pid or atom name of the channel to fetch.
    Returns a Channel struct, to be used in UrbitEx functions involving PUT requests.
  """
  def read(pid \\ :main), do: GenServer.call(pid, :get)
  @doc """
    Subscribes to a channel in order to receive the SSE events (after parsing by the UrbitEx default reducer) it publishes.
    Takes a pid or atom name of the channel to subscribe to, and the pid of the subscriber process.
  """
  def consume_feed(channel_pid, consoomer_pid), do:
    GenServer.cast(channel_pid, {:consume, consoomer_pid})
  @doc """
    Deletes the subscription to a channel. No events will be received after calling this function.
    Takes a pid or atom name of the channel to subscribe from, and the pid of the subscriber process.
  """
  def wean(channel_pid, consoomer_pid), do:
    GenServer.cast(channel_pid, {:wean, consoomer_pid})
  @doc """
    Subscribes to a raw Eyre SSE pipeline in order to receive the raw SSE events it publishes.
    Takes a pid or atom name of the channel to subscribe to, and the pid of the subscriber process.
  """
  def consume_raw(channel_pid, consoomer_pid), do:
    GenServer.cast(channel_pid, {:consume_raw, consoomer_pid})
  @doc """
    Deletes the subscription to raw events.
    Takes a pid or atom name of the channel to unsubscribe from, and the pid of the subscriber process.
  """
  def wean_raw(channel_pid, consoomer_pid), do:
    GenServer.cast(channel_pid, {:wean_raw, consoomer_pid})

  # client
  def start_link(options \\ [], name \\ :main) when is_list(options) do
    GenServer.start_link(__MODULE__, new(options), name: name)
  end

  def start(options \\ [], name \\ :main) when is_list(options) do
    GenServer.start(__MODULE__, new(options), name: name)
  end

  def connect(pid \\ :main), do: GenServer.call(pid, :connect)

  defp new(opts \\ []) do
    path =
      "/~/channel/#{System.os_time(:millisecond)}-#{:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)}"
    struct(__MODULE__, Keyword.put(opts, :path, path))
  end

  @spec add_event(atom | pid | {atom, any} | {:via, atom, any}, any) :: :ok
  def add_event(pid \\ :main, event) do
    GenServer.cast(pid, {:save_event, event})
  end

  def save_action(pid \\ :main, id) do
    GenServer.cast(pid, {:save_state, :last_action, id})
  end

  def save_ack(pid \\ :main, id) do
    GenServer.cast(pid, {:save_state, :last_ack, id})
  end
  # todo save the id!!
  def save_subscription(pid \\ :main, subscription) do
    GenServer.cast(pid, {:subscribe, subscription})
  end

  def check_stream() do
    Process.send_after(self(), :timer, 30_000)
  end

  def check_ack() do 
    :timer.send_interval(1_000, :ack)
  end

  ## server
  @impl true
  def init(channel) do
    check_stream()
    check_ack()
    {:ok, channel}
  end

  @impl true
  def handle_call(:get, _from, channel), do: {:reply, channel, channel}

  @impl true
  def handle_call(:connect, _from, channel) do
    session = Session.read(channel.parent)

    new_channel =
      with :ok <- API.open_channel(session, channel),
           {:ok, _ok } <- API.start_sse(session, channel) do
        send(channel.parent, {:channel_added, channel.name, self()})
        %{channel | status: :open}
      else
        {:error, _} -> %{channel | status: :error}
      end

    {:reply, :ok, new_channel}
  end

  ## handle SSE

  @impl true
  def handle_info(%HTTPoison.AsyncStatus{}, channel) do
    {:noreply, channel}
  end
  @impl true
  # ignore keep-alive messages
  def handle_info(%{chunk: "\n"}, channel) do
    {:noreply, %{channel | last_event: Time.utc_now()}}
  end
  @impl true
  def handle_info(%{chunk: ":\n"}, channel) do
    {:noreply, %{channel | last_event: Time.utc_now()}}
  end
  @impl true
  def handle_info(%{chunk: ""}, channel) do
    {:noreply, channel}
  end

  @impl true
  def handle_info(%{chunk: data}, channel) do
    parse_stream(data)
    {:noreply, channel}
  end
  @impl true
  def handle_info({:handle_valid_message, id, event}, channel) do
    if channel.autoack, do: API.ack(UrbitEx.get(), channel, id)
    broadcast(channel.raw_consumers, event)
    if channel.keep_state, do: UrbitEx.Reducer.default_reducer(event)
    {:noreply, %{channel | last_sse: id, last_event: Time.utc_now()}}
  end

  @impl true
  def handle_info({:handle_truncated_message, id, message}, channel) do
    new_channel = %{channel | last_sse: id, truncated_event: message}
    {:noreply, new_channel}
  end

  @impl true
  def handle_info({:stack_truncated_message, message}, channel) do
    tm = channel.truncated_event <> message

    case Jason.decode(tm) do
      {:ok, json} ->
        send(self(), {:handle_valid_message, channel.last_sse, json})
        {:noreply, %{channel | truncated_event: ""}}

      {:error, _r} ->
        {:noreply, %{channel | truncated_event: tm}}
    end
  end

  ### private functions used by handle infos

  defp parse_stream(event) do
    rr = ~r(id:\s\d+\ndata:\s.+?}\n\n)
    messages = String.split(event, rr, include_captures: true, trim: true)

    for msg <- messages do
      check_truncated(msg)
    end
  end

  defp check_truncated(msg) do
    r = ~r(^id:\s\d+\ndata:\s)
    case String.split(msg, r, include_captures: true, trim: true) do
      [event_id, data] ->
        [id] = Regex.run(~r(\d+), event_id)
        handle_seemingly_valid(id, data)

      _ ->
        handle_truncated(msg)
    end
  end

  defp handle_seemingly_valid(id_string, data) do
    id = String.to_integer(id_string)
    case Jason.decode(data) do
      {:ok, json} -> send(self(), {:handle_valid_message, id, json})
      {:error, _r} -> handle_truncated(id, data)
    end
  end

  # it has an id if it's the first piece of a long message

  defp handle_truncated(id, string) do
    send(self(), {:handle_truncated_message, id, string})
  end

  # when it's continuing the former
  defp handle_truncated(string) do
    send(self(), {:stack_truncated_message, string})
  end

  ## handle parsed events
  @impl true
  def handle_info({:save, tuple}, channel) do
    key = GenServer.call(channel.parent, {:save, tuple})
    broadcast(channel.consumers, {:data_set, key})
    {:noreply, channel}
  end
  @impl true
  def handle_info({:update, tuple}, channel) do
    broadcast(channel.consumers, {:data_updated, tuple})
    send(channel.parent, {:update, tuple})
    {:noreply, channel}
  end
  @impl true
  def handle_info({:add, tuple}, channel) do
    broadcast(channel.consumers, {:data_added, tuple})
    # I actually can do calls to this, not sends
    send(channel.parent, {:add, tuple})
    {:noreply, channel}
  end
  @impl true
  def handle_info({:add_or_update, tuple}, channel) do
    broadcast(channel.consumers, {:data_added_or_updated, tuple})
    send(channel.parent, {:add_or_update, tuple})
    {:noreply, channel}
  end
  @impl true
  def handle_info({:remove, tuple}, channel) do
    broadcast(channel.consumers, {:data_removed, tuple})
    send(channel.parent, {:remove, tuple})
    {:noreply, channel}
  end
  @impl true
  def handle_info({:send, event}, channel) do
    broadcast(channel.consumers, event)
    {:noreply, channel}
  end
  @impl true
  def handle_info(:timer, channel) do
    baseline = Time.utc_now()
    diff = (Time.diff(baseline, channel.last_event))
    if diff > 30 do
      API.restart_sse(UrbitEx.get(channel.parent), channel)
    end
    check_stream()
    {:noreply, channel}
  end
  def handle_info(:ack, channel) do
    if channel.last_sse > channel.last_ack do 
      API.ack(UrbitEx.get(channel.parent), channel, channel.last_sse)
      {:noreply, %{channel | last_ack: channel.last_sse}}
    else
      {:noreply, channel}
    end
  end

  @impl true
  def handle_info(_message, channel) do
    {:noreply, channel}
  end


  ## handle casts

  @impl true
  def handle_cast({:subscribe, subscription}, channel) do
    channel = %{channel | subscriptions: [subscription | channel.subscriptions]}
    {:noreply, channel}
  end
  @impl true
  def handle_cast({:consume, pid}, channel) do
    IO.inspect(pid, label: :consooming)
    {:noreply, %{channel | consumers: [pid | channel.consumers]}}
  end
  @impl true
  def handle_cast({:wean, pid}, channel) do
    IO.inspect(pid, label: :stopped_consooming)
    {:noreply, %{channel | consumers: List.delete(channel.consumers, pid)}}
  end
  @impl true
  def handle_cast({:consume_raw, pid}, channel) do
    IO.inspect(pid, label: :consooming_raw)
    {:noreply, %{channel | raw_consumers: [pid | channel.raw_consumers]}}
  end
  @impl true
  def handle_cast({:wean_raw, pid}, channel) do
    IO.inspect(pid, label: :stopped_consooming_raw)
    {:noreply, %{channel | raw_consumers: List.delete(channel.raw_consumers, pid)}}
  end

  @impl true
  def handle_cast({:save_state, key, data}, channel) do
    {:noreply, Map.put(channel, key, data)}
  end

  defp broadcast(consumers, message) do
    consumers |> Enum.each(&send(&1, message))
  end
end
