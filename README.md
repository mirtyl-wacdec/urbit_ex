# UrbitEx

UrbitEx is an Elixir package which allows you to connect to a running Urbit instance.
It is a batteries-included, opinionated library, with functionality baked in to build an Urbit client right away, with little need to add additional logic.
But it also exposes low-level APIs if you feel like rolling your own logic on raw Urbit primaries, e.g. poke, scry, raw SSE event handling, etc.

## Installation
The package is published at Hex, please look at https://hex.pm/packages/urbit_ex.

The package can be installed by adding `urbit_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:urbit_ex, "~> 0.7.2"}
  ]
end
```

Or clone this repo and point `mix.exs` to its location:
```elixir
def deps do
  [
    {:urbit_ex, path: "path/to/folder"}
  ]
end
```

## Use
Big changes since last version!
After adding it to your dependencies, connect to an Urbit ship by running: 
```elixir
{:ok, pid} = UrbitEx.start_link(url, code, name \\ :urbit)
```
Or 
```elixir 
{:ok, pid} = UrbitEx.start(url, code, name \\ :urbit)
``` 
if you want an unlinked process. e.g. 
```elixir
{:ok, pid} = UrbitEx.start_link("http://localhost", "sampel-sampel-sampel-sampel")
```
This will login to your Urbit ship and start a GenServer with the passed name atom keeping the state for your Urbit session. and start the EventSource pipeline. You can fetch your Urbit session's state any time with 
```elixir
UrbitEx.get(name \\ :urbit)
```

You will need to subscribe to gall apps in order to your Urbit ship to start sending any events to Elixir. You can do so by adding an eyre channel. As most things in these API, there's two ways of doing that.
1. The easy way:
```elixir
UrbitEx.new_channel(name \\ :main)
```

This will open a new channel (by default called `:main`) and subscribe to all the apps that Landscape subscribes to. It will also activate the default reducer, which automatically processes Urbit events and keeps state of your session in the `UrbitEx.Session` GenServer.

2. The hard way:
```elixir 
UrbitEx.Session.add_channel(name: main, parent: :urbit, keep_state: true)
```
This will open an eyre channel and a Channel GenServer to keep its state. You then must manually subscribe to gall apps in order to receive events. You do so by passing a list of subscriptions to 
```elixir 
UrbitEx.API.subscribe(session, channel, list)
```
e.g.
```elixir
session = UrbitEx.get()
channel = UrbitEx.Channel.read(:main)
list = [
        %{app: "metadata-store", path: "/all"},
        %{app: "group-view", path: "/all"},
        %{app: "group-store", path: "/groups"},
        %{app: "graph-store", path: "/keys"},
        %{app: "graph-store", path: "/updates"},
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
        %{app: "dm-hook", path: "/updates"}
      ]
UrbitEx.API.subscribe(session, channel, list)
```
You can add multiple channels with separate or overlapping subscriptions.

Subscription will trigger your Urbit ship to start sending Server Side Events (SSE, aka EventSource, EventStream). 
UrbitEx has a built-in reducer (see `reducer.ex` in the repo) to parse and process the raw events sent by your Urbit ship. 
The built-in reducer does two things: 
1. If the channel was started with the `keep_state` flag given as `true`, the Session struct will keep the basic state of your session: pending notifications, unreads, pending group joins, pending invites, channel metadata, contacts; i.e. all the state that Landscape keeps and any Urbit client would need to function.
2. The reducer parses urbit events and then broadcasts them to any consumers of the Channel GenServer. You can subscribe to these events with:
```elixir
UrbitEx.Channel.consume_feed(channel, consumer_pid)
```
e.g.
```elixir
UrbitEx.Channel.consume_feed(:main, self())
```
You can then handle those events as you wish. To see the format of the events sent, check the `channel.ex` and `reducer.ex` files in the repo.

If you would prefer to parse Urbit events on your own and not use the default reducer, you can subscribe to the raw eyre SSE events by using:
```elixir
UrbitEx.Channel.consume_raw(channel, consumer_pid)
```
You can stop the subscriptions by using:
```elixir
UrbitEx.Channel.wean(channel, consumer_pid)
UrbitEx.Channel.wean_raw(channel, consumer_pid)
```
respectively. Ad-hoc consumption and weaning is very convenient if you want to handle an event inside `Task.async`, for example.

For version 0.6.0 full functionality (at least Landscape-equivalent) for all Gall Apps has been implemented. 

You can easily create, join, leave, delete groups and channels, post messages and edit them, all Landscape functionality and then some (e.g. ban comets from your group!).
eg.

```elixir
r = UrbitEx.Resource.new("dopzod", "urbit-help")
message = "My Elixir API is too awesome, please help")
UrbitEx.API.Graph.send_message(session, r, message)
```

Please look at all files inside the `api/` folder for individual module docs. There's even support for virtual terminal! Check out `api/gall/herm.ex` for detail.

Structs added as soft type specs for most data structures, e.g. `Resource`, `Graph`, `Post`, `Node`, Notifications, etc. Tildes are generally added or removed automatically as necessary to interact with Eyre.

This library also includes an implementation of Herb, a way to evaluate `dojo` code from the outside. You can call it passing the loopbackport and some dojo command.

```elixir
UrbitEx.herb(12321, "+trouble")
```

For more documentation (much improved), look inside the repo or at https://hexdocs.pm/urbit_ex/0.6.5/UrbitEx.API.html#content.
