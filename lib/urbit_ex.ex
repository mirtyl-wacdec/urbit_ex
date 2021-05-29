defmodule UrbitEx do
  alias UrbitEx.{Server, Handler, API}
  @url System.get_env("UR_URL")
  @code System.get_env("UR_CODE")
  @moduledoc """
  Main API for the UrbitEx Package.
  Includes functions to initiate your Urbit session, subscribe to main event sources
  and set up logic to handle events.
  """

  @doc """
    Starts the Urbit instance. Takes the url where your ship is running, the `+code`,
    and an optional name for the server (handy if you're running multiple ones).

  ## Examples

      iex> {:ok, pid} = UrbitEx.start("http://localhost:8080", "sampel-dozzod-mirtyl-marzod")

  """
  def start_link(url, code, name \\ :urbit_server) do
    {:ok, pid} = Server.start_link([url: url, code: code], name)
  end

  @doc """
    Starts the Urbit instance without a process link.
    Takes the url where your ship is running, the `+code`,
    and an optional name for the server (handy if you're running multiple ones).

  """

  def start(url, code, name \\ :urbit_server) do
    Server.start([url: url, code: code], name)
  end

  @doc """
    Fetches pid of the GenServer keeping the session state.
  """

  def get_pid do
    Process.whereis(:urbit_server)
  end

  @doc """
    Sets process as consumer of the Urbit Ship's Eventstream.
    Every Urbit event will be sent from the Urbit GenServer to the process pid passed.
  """
  def consume_feed(pid) do
    GenServer.cast(:urbit_server, {:consume, pid})
  end

  @doc """
  Subscribes to event streams. Takes a list of subscriptions.
  If it's a single subscription you want just wrap it in a list.
  Individual subscriptions are maps: `%{app: app, path: path}
  """
  def subscribe(subscriptions) do
    GenServer.cast(:urbit_server, {:subscribe, subscriptions})
  end

  @doc """
    Fetches the current session state from the GenServer.
  """

  def get_state() do
    GenServer.call(:urbit_server, :get)
  end

  @doc """
    Starts a recursive loop that reacts to events received from your Urbit ship.
    Takes a single argument, a function that will process received messages.
    ## Examples

       ```
       function = fn
         %{"json" => json} -> IO.inspect(json)
         _message -> IO.inspect(:other_app)
       end
       UrbitEx.recv(function)
    ```

  """
  def recv(function) do
    receive do
      message ->
        function.(message)
    after
      1_000 -> "nothing after 1s"
    end

    recv(function)
  end

  @doc """
  Function provided for testing purposes. It will subscribe to the same event streams as the Landscape client does.
  Set your url and code as module attributes and iterate your handling logic fast.
  Returns the pid of the GenServer started.
  Check the state with get_state() and you can browse all events received, etc.
  """

  def test() do
    {:ok, task} =
      Task.start_link(fn ->
        {:ok, pid} = UrbitEx.start(@url, @code)
        subscribe(landscape_subs())
        consume_feed(self)

        UrbitEx.recv(fn
          %{"json" => json} -> Handler.general(json)
          %{"err" => err} -> IO.inspect(err, label: :error)
          %{"ok" => _} -> :ok
        end)
      end)
  end

  def dod() do
    s = get_state()
    UrbitEx.API.Profile.update_bio(s, "chillin")
  end

  defp landscape_subs() do
    [
      %{app: "group-view", path: "/all"},
      %{app: "group-store", path: "/groups"},
      %{app: "graph-store", path: "/keys"},
      %{app: "graph-store", path: "/updates"},
      %{app: "metadata-store", path: "/all"},
      %{app: "invite-store", path: "/all"},
      %{app: "launch", path: "/all"},
      %{app: "weather", path: "/all"},
      %{app: "contact-store", path: "/all"},
      %{app: "hark-store", path: "/updates"},
      %{app: "hark-graph-hook", path: "/updates"},
      %{app: "hark-group-hook", path: "/updates"},
      %{app: "settings-store", path: "/all"},
      %{app: "s3-store", path: "/all"},
      %{app: "contact-pull-hook", path: "/nacks"}
    ]
  end

  def test_subs() do
    [
      %{app: "metadata-store", path: "/all"},
      %{app: "group-store", path: "/groups"},
      %{app: "group-view", path: "/all"},
      %{app: "contact-pull-hook", path: "/nacks"},
      %{app: "graph-store", path: "/keys"},
      %{app: "graph-store", path: "/updates"}
    ]
  end
end
