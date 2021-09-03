defmodule UrbitEx.Session do
  @moduledoc """
    GenServer to keep state of an Urbit Session.
    Creates a struct keeping track of global data, and client functions to add and remove channels.
  """
  alias UrbitEx.{API, Channel, S3Config, Unread, Resource, Notification}
  @derive Jason.Encoder
  use GenServer

  defstruct ship: "",
            url: "",
            cookie: "",
            keys: [],
            groups: [],
            channels: [],
            unread: [],
            profile: %{},
            contacts: %{},
            invites: [],
            metadata: [],
            notifications: %{},
            group_joins: [],
            pending_dms: [],
            s3: %S3Config{},
            settings: %{},
            status: :init

  @doc """
    Starts the GenServer as a linked process.
    Takes a keyword list with initialization options, and an atom to name the process.
  """

  def start_link(options \\ [], name \\ :urbit) when is_list(options) do
    GenServer.start_link(__MODULE__, struct(__MODULE__, options), name: name)
  end

  @doc """
    Starts the GenServer as an unlinked process.
    Takes a keyword list with initialization options, and an atom to name the process.
  """
  def start(options \\ [], name \\ :urbit) when is_list(options) do
    GenServer.start(__MODULE__, struct(__MODULE__, options), name: name)
  end

  @doc """
    Resets state with a new url and cookie.
    Takes a pid or atom name of the server to reset, an url string and a cookie string.
  """

  def reconnect(pid, url, cookie), do: GenServer.call(pid, {:login, url, cookie})

  @doc """
    Creates an eyre channel and attackes it to the session
    Takes a keyword list with three optional keys: `:name` to give the new channel, `:parent`, name or pid of the parent session, and `:keep_state`, a boolean to determine whether the channel should send events for automatic state-keeping by the parent session.
    Takes a pid or atom name of the server to reset, an url string and a cookie string.
  """
  def add_channel(opts \\ []) do
    name = opts[:name] || :main
    parent = opts[:parent] || :urbit
    keep_state = opts[:keep_state] || true
    {:ok, cpid} = Channel.start([parent: parent, keep_state: keep_state, name: name], name)
    # todo error handling
    Channel.connect(cpid)
  end

  @doc """
    Closes an open eyre channel.
    Takes a pid or atom name of the parent session, and atom name or pid of the channel to close.
    Returns :ok
  """

  def close_channel(pid \\ :urbit, name) do
    s = read(pid)
    c = Channel.read(name)
    API.close_channel(s, c)
    cpid = Process.whereis(name)
    GenServer.cast(pid, {:channel_closed, cpid})
    Process.exit(cpid, :kill)
    :ok
  end

  @doc """
  Returns the state of the Session.
  Takes a pid or atom name of the Session process.
  Aliased as `UrbitEx.get`.
  """

  def read(pid \\ :urbit) do
    GenServer.call(pid, :get)
  end

  def save_contacts(pid, contacts), do: GenServer.cast(pid, {:save_contacts, contacts})
  def set_value(pid, key, value), do: GenServer.cast(pid, {:save_entry, key, value})
  def add(pid, key, item), do: GenServer.cast(pid, {:add, key, item})

  # server
  @impl true
  def init(session) do
    {:ok, session}
  end
  @impl true
  def handle_call({:reconnect, url, cookie} , _from, session) do
    [ship] = Regex.run(~r|~.+=|, cookie)
    ship = String.replace(ship, ~r|[~=]|,"")
    ns = %{session | url: url, cookie: cookie, ship: ship}
    {:reply, ns, ns}
  end

  @impl true
  def handle_call(:get, _from, session) do
    {:reply, session, session}
  end

  @impl true
  def handle_call({:save, {:contacts, contacts}}, from, session) do
    profile = contacts[UrbitEx.Utils.add_tilde(session.ship)]
    new_session = %{session | contacts: contacts, profile: profile}
    {:reply, :contacts, new_session}
  end
  @impl true
  def handle_call({:save, {key, value}}, from, session) do 
    ns = Map.put(session, key, value)
    {:reply, key, ns}
  end
  @impl true
  def handle_cast({:channel_closed, pid}, session) do
    new_session = %{session | channels: List.delete(session.channels, pid)}
    IO.inspect("closing channel")
    {:noreply, new_session}
  end


  @impl true
  def handle_info({:channel_added, name, pid}, session) do
    IO.inspect("channel #{name} added")
    new_session = %{session | channels: [pid | session.channels]}
    {:noreply, new_session}
  end

  # TODO move data processing to reducer, keep genserver as dumb as possible
  @impl true
  defp lookup_notes(type) when is_atom(type) do 
    case type do 
      :mention -> :mentions
      :message -> :messages
      :link -> :links
      :post -> :posts
      :note -> :notes
      :comment -> :comments
      :"add-members" -> :joined
      :"remove-members" -> :left 
    end
  end

  def handle_info({:add_or_update, {:notifications, notif}}, session) do
    type = lookup_notes(notif.type)
    notes = session.notifications[type]
    filtered = Enum.filter(notes, & &1.resource != notif.resource)
    new = [notif | filtered]
    notifications = Map.put(session.notifications, type, new)
    {:noreply, %{session | notifications: notifications}}
  end

  @impl true
  def handle_info({:add, {key, item}}, session) do
    {:noreply, Map.put(session, key, [item | Map.get(session, key)])}
  end
  @impl true
  def handle_info({:remove, {:notifications, type, resource, _index, _time}}, session) do
    notifications = session.notifications[lookup_notes(type)]
    filtered = Enum.filter(notifications, & &1.resource != resource)
    new = Map.put(session.notifications, lookup_notes(type), filtered)
    {:noreply, %{session | notifications: new}}
  end

  @impl true
  def handle_info({:remove, {key, item}}, session) do
    {:noreply, Map.put(session, key, List.delete(Map.get(session, key), item))}
  end
  @impl true
  def handle_info({:add_or_update, {:contacts, ship, key, value}}, session) do
    to_update = session.contacts[ship]
    new_contacts =
      if to_update do
      updated = Map.put(to_update, key, value)
      Map.put(session.contacts, ship, updated)
    else
      contact = %{key => value}
      Map.put(session.contacts, ship, contact)
    end
    {:noreply, %{session | contacts: new_contacts}}
  end

  # this applies to metadata and groups
  @impl true
  def handle_info({:add_or_update, {key, item}}, session) do
    list = Map.get(session, key)
    old = list |> Enum.find(& &1.resource == item.resource)
    if old do
      newlist = [item | List.delete(list, old)]
      ns = Map.put(session, key, newlist)
      {:noreply, ns}
    else
      {:noreply, Map.put(session, key, [item | list])}
    end
  end
  @impl true
  def handle_info({:update, {:unread, :add_count, resource, index, timestamp}}, session) do
    old = Enum.find(session.unread, & &1.resource == resource && &1.index == index && &1.count)
    new = if old do
      %{old | last: timestamp, count: old.count + 1}
    else
      Unread.newcount(resource, index, timestamp)
    end
    new_unreads = [new | List.delete(session.unread, old)]
    {:noreply, %{session | unread: new_unreads}}
  end
  @impl true
  def handle_info({:update, {:unread, :clear_count, resource, index}}, session) do
    old = Enum.find(session.unread, & &1.resource == resource && &1.index == index && &1.count)
    new_unreads = List.delete(session.unread, old)
    {:noreply, %{session | unread: new_unreads}}
  end
  @impl true
  def handle_info({:update, {:unread, :add_each, resource, index,timestamp}}, session) do
    old = Enum.find(session.unread, & &1.resource == resource && &1.each)
    new = if old do
      %{old | last: timestamp, each: [ index | old.each]}
    else
      Unread.neweach(resource, index, timestamp)
    end
    new_unreads = [new | List.delete(session.unread, old)]
    {:noreply, %{session | unread: new_unreads}}
  end
  @impl true
  def handle_info({:update, {:unread, :clear_each, resource, index }}, session) do
    # todo fix this
    old = Enum.find(session.unread, & &1.resource == resource && &1.each)
    if old do 
      new = %{old | each: List.delete(old.each, index)}
      new_unreads = [new | List.delete(session.unread, old)]
      {:noreply, %{session | unread: new_unreads}}
    else
      {:noreply,  session}
    end
  end
  @impl true
  def handle_info({:update, {:groups, :add_members, resource, members}}, session) do
    group = session.groups |> Enum.find(& &1.resource == resource)
    if group do
      updated_group = %{group | members: group.members ++ members}
      new_groups = [updated_group | List.delete(session.groups, updated_group)]
      {:noreply, %{session | groups: new_groups}}
    else
      {:noreply, session}
    end
  end
  @impl true
  def handle_info({:update, {:groups, :remove_members, resource, members}}, session) do
    group = session.groups |> Enum.find(& &1.resource == resource)
    updated_group = %{group | members: group.members -- members}
    new_groups = [updated_group | List.delete(session.groups, updated_group)]
    {:noreply, %{session | groups: new_groups}}
  end
  @impl true
  def handle_info({:update, {:groups, :policy, resource, diff}}, session) do
    group = session.groups |> Enum.find(& &1.resource == resource)
    updated_group = %{group | policy: diff["replace"]}
    new_groups = [updated_group | List.delete(session.groups, updated_group)]
    {:noreply, %{session | groups: new_groups}}
  end
  @impl true
  def handle_info({:update, {:groups, :tags, resource, tag, ships}}, session) do
    group = session.groups |> Enum.find(& &1.resource == resource)
    updated_group = %{group | tags: %{tag => ships}}
    new_groups = [updated_group | List.delete(session.groups, updated_group)]
    {:noreply, %{session | groups: new_groups}}
  end
  @impl true
  def handle_info({:update, {:s3, struct}}, session) do
    data = Map.merge(session.s3, struct, fn (_k, v1, v2) ->
      s1 = Jason.encode!(v1)
      s2 = Jason.encode!(v2)
      if String.length(s1) > String.length(s2), do: v1, else: v2
    end)
    {:noreply, %{session | s3: data}}
  end
  @impl true
  def handle_info({:update, {:s3, :add_bucket, bucket}}, session) do
    newbucket = [bucket | session.s3.buckets]
    news3 = Map.put(session.s3, :buckets, newbucket)
    {:noreply, %{session | s3: news3}}
  end
  @impl true
  def handle_info({:update, {:s3, :remove_bucket, bucket}}, session) do
    newbucket = List.delete(session.s3.buckets, bucket)
    news3 = Map.put(session.s3, :buckets, newbucket)
    {:noreply, %{session | s3: news3}}
  end
  @impl true
  def handle_info({:update, {:s3, key, value}}, session) do
    ns3 = Map.put(session.s3, key, value)
    {:noreply, %{session | s3: ns3}}
  end
  @impl true
  def handle_info({:update, {_key, _item}}, session) do
    {:noreply, session}
  end
end

# login: 370310366L
# contrasena: router2727