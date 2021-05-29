# UrbitEx

UrbitEx is an Elixir package to connect to a running Urbit instance.

## Installation
The package is published at Hex, please look at https://hex.pm/packages/urbit_ex.

The package can be installed by adding `urbit_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:urbit_ex, "~> 0.5.7"}
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
After adding it to your dependencies, connect to an Urbit ship by running: 
`{:ok, pid} = UrbitEx.start(url, code)`
e.g. `{:ok, pid} = UrbitEx.start("http://localhost", "sampel-sampel-sampel-sampel")`

This will start your Urbit ship as a GenServer and start the EventSource pipeline.
You will need to subscribe to gall apps in order to your Urbit ship to start sending any events. You can do so by running:
`UrbitEx.subscribe/2`.

To react to events, set up your own function to react to received events and pass it to `UrbitEx.recv/1`.
e.g. 
```elixir
function = fn
  %{"json" => json} -> 
    case json  do
      %{"graph-update" => data } -> IO.inspect(data, label: :chat_message)
      _ -> IO.inspect(:some_other_app)
    end
  _message -> IO.inspect(:other_message)
end
UrbitEx.recv(function)
```

You can query the GenServer state for debug purposes by running:
`UrbitEx.get_state()`.

For version 0.5.0 Graph Store and Group Store endpoints have been added.
You can now easily create, join, leave, delete groups and channels, post messages and edit them, all Landscape functionality and then some (e.g. ban comets from your group!).
eg.
```elixir
r = UrbitEx.Resource.new("dopzod", "urbit-help")
message = "My Elixir API is too awesome, please help")
UrbitEx.API.Graph.send_message(session, r, message)
```

As of now you can build a Chatbot easily with the API. There's an easter egg inside already, see if you find it.

Structs added as type specs for `Resource`, `Graph`, `Post` and `Node`. Tildes are generally added or removed automatically as necessary to interact with Eyre.

This library also includes an implementation of Herb, a way to evaluate `dojo` code from the outside. You can call it passing the loopbackport and some dojo command.

```elixir
UrbitEx.herb(12321, "+trouble")
```


For more documentation (much improved), look inside the repo or at https://hexdocs.pm/urbit_ex/0.5.5/UrbitEx.API.html#content.