defmodule UrbitEx do
  alias UrbitEx.{Session, Channel, API, Terminal}

  @moduledoc """
  Main API for the UrbitEx Package.
  Includes functions to initiate your Urbit session, subscribe to main event sources
  and set up logic to handle events.
  """

  @doc """
    Logs in to Urbit to an Urbit instance and starts an unlinked GenServer. Takes the url where your ship is running, the `+code`,
    and an optional name for the server (handy if you're running multiple ones).

  ## Examples

      iex> {:ok, pid} = UrbitEx.start("http://localhost:8080", "sampel-dozzod-mirtyl-marzod")

  """
  def start(url, code, name \\ :urbit) do
    case API.login(url, code) do
      {:error, error} -> {:error, error}
      {:ok, url, ship, cookie} ->
        Session.start([url: url, ship: ship, cookie: cookie], name)
    end
  end

  @doc """
    Logs in to Urbit to an Urbit instance and starts a linked GenServer. Takes the url where your ship is running, the `+code`,
    and an optional name for the server (handy if you're running multiple ones).

  ## Examples

      iex> {:ok, pid} = UrbitEx.start("http://localhost:8080", "sampel-dozzod-mirtyl-marzod")

  """
  def start_link(url, code, name \\ :urbit) do
    case API.login(url, code) do
      {:error, error} -> {:error, error}
      {:ok, url, ship, cookie} ->
        Session.start_link([url: url, ship: ship, cookie: cookie], name)
    end
  end

  @doc """
    Reconnects to a running Urbit instance without logging in, provided you have stored a valid cookie from a previous session.
    Starts a Session GenServer.
    Takes a url string and a cookie string, and a boolean; if true, the Session is started as a linked process.
    Returns an {:ok, pid} tuple.
  ## Examples

      iex> {:ok, pid} = UrbitEx.reconnect("http://localhost:8080", "urbauth-~sampel-planet-0v4...")

  """

  def reconnect(url, cookie, link \\ false) do
    [ship] = Regex.run(~r/(?<=~)[a-z]+[^=]*/, cookie)
    case link do
      true -> Session.start_link([url: url, cookie: cookie, ship: ship])
      false -> Session.start([url: url, cookie: cookie, ship: ship])
    end
  end

  @doc """
    Fetches the state of a running Urbit Session.
    Returns a Session struct.
  """

  def get(pid \\ :urbit), do: Session.read(pid)
  @doc """
    Fetches the state of a channel, `:main` as default.
    Returns a Channel struct.
  """
  def getc(pid \\ :main), do: Channel.read(pid)


  @doc """
     Shuts down an Urbit Session and associated Eyre Channels. Returns `true`.
  """
  def kill(name \\ :urbit) do
    s = get(name)
    for pid <- s.channels do
      c = Channel.read(pid)
      API.close_channel(s, c)
      Process.exit(pid, :kill)
    end
    Process.exit(Process.whereis(name), :kill)
  end

  @doc """
    Starts an Eyre channel subscribed to the same subscriptions as Landscape does.
    Returns a UrbitEx.Session struct.
  """

  def new_channel(name \\ :main) when is_atom(name) do
    s = get()
    Session.add_channel(name: name)
    c = Channel.read(name)
    subs = landscape_subs()
    API.subscribe(s, c, subs)
  end

  @doc """
    Starts a new channel subscribed to `herm`, the virtual terminal.
    Returns a UrbitEx.Channel struct.
    You can pass that struct to the UrbitEx.Terminal module functions and interact with the terminal.
  """

  def terminal() do
    s = get()
    Session.add_channel(name: :term)
    c = Channel.read(:term)
    Terminal.subscribe(s, c)
    c
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
      %{app: "contact-pull-hook", path: "/nacks"},
      # %{app: "contact-pull-hook", path: "/all"},
      %{app: "dm-hook", path: "/updates"}
      # %{app: "herm", path: "/session/"}
    ]
  end
end
