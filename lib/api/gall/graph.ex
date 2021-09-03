defmodule UrbitEx.API.Graph do
  alias UrbitEx.{Utils, API, Airlock, Resource, Actions, GraphStore}

  @moduledoc """
    Client API to interact with graphs on Urbit.
    Create channels, delete them, send messages, add posts, etc.
    All interaction with present Graph Store based applications is here.
  """

  # Channels

  @doc """
  Joins a channel. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers two `graph-update` event, one with a list of `keys` and for `add-graph`.
  Eyre returns a 200 response.
  """

  def join_channel(session, resource) do
    json = GraphStore.join_resource(resource)
    endpoint = "/spider/graph-view-action/graph-join/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Leaves a channel. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `graph-update` event.
  Eyre returns a 200 response.
  """

  def leave_channel(session, resource) do
    json = GraphStore.leave_channel(resource)
    endpoint = "/spider/graph-view-action/graph-leave/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Creates a channel in a group. Takes an UrbitEx.Session struct an UrbitEx.Resource struct (for the group),
  a title string, a name string (lower ascii, no spaces), a description string, and a channel type atom (strings work too, it's all json anyway).
  As in group names, Landscape enforces title and name being similar, no real need for that.
  Types can be `:chat` for Chats, `:publish` for Notebooks or `:link` for Collections.
  Successful creation triggers one `metadata-update`event and one `graph-update` event.
  Eyre returns a 200 response.
  """

  def create_group_channel(session, group, title, name, description, type) do
    json = GraphStore.create_channel(session.ship, group, title, name, description, type, :group)
    apply_channel_creation(session, json)
  end

  @doc """
  Creates a private channel. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct (for the group),
  a title string, a name string (lower ascii, no spaces), a description string, a channel type atom
  (strings work too, it's all json anyway), and a list of invitees.
  As in group names, Landscape enforces title and name being similar, no real need for that.
  Types can be `:chat` for Chats, `:publish` for Notebooks or `:link` for Collections.
  Setting invitees at resource creation works unlike with groups.
  Note that private "chat" channels are in effect DMs and will show up as DMs in Landscape,
  although they will strangely if you don't follow Landscape naming (see below).
  Successful creation triggers one `metadata-update`event and one `graph-update` event.
  Eyre returns a 200 response.
  """

  def create_private_channel(session, title, name, description, type, invitees \\ []) do
    invitees = Enum.map(invitees, &Utils.add_tilde/1)

    json =
      GraphStore.create_channel(
        session.ship,
        "",
        title,
        name,
        description,
        type,
        :private,
        invitees
      )

    apply_channel_creation(session, json)
  end

  def create_open_channel(session, title, name, description, type) do
    json = GraphStore.create_channel(session.ship, "", title, name, description, type, :public)
    apply_channel_creation(session, json)
  end

  def await_channel() do
    receive do
      {:add_graph, resource, validator} -> {:graph_added, resource, validator}
      {:join_group_progress, resource, "no-perms"} -> {:no_perms, resource}
    end
  end

  defp apply_channel_creation(session, json) do
    endpoint = "/spider/graph-view-action/graph-create/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Deletes a channel. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `metadata-update`event and one `graph-update` event.
  Unless it's a private channel then the `metadata-update` event is replaced by a `group-update` one (??).
  Eyre returns a 200 response.
  """

  def delete_channel(session, resource) do
    json = GraphStore.delete_channel(resource)
    endpoint = "/spider/graph-view-action/graph-delete/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Enables the group feed in a group. Takes an UrbitEx.Session struct an UrbitEx.Resource struct,
  and the permission setting. Can be "host-feed", "admin-feed",  or "" (empty) to allow everyone to post on the feed.
  Triggers one `metadata-update` and one `graph-update` event.
  Validator for group feeds is `graph-validator-post`, cf: `graph-validator-chat` or `graph-validator-publish`.
  Eyre returns a 200 response.
  """

  def enable_group_feed(session, group, permission) do
    json = GraphStore.enable_group_feed(group, permission)
    endpoint = "/spider/graph-view-action/graph-create-group-feed/resource.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Disables the group feed in a group. Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  Triggers one `metadata-update` and one `graph-update` event.
  Eyre returns a 200 response.
  """

  def disable_group_feed(session, group) do
    json = GraphStore.disable_group_feed(group)
    endpoint = "/spider/graph-view-action/graph-disable-group-feed/json.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  ## Scries

  @doc """
  Fetches latest nodes from any channel.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, and an option keyword list.
  Option keys can be `:count, with an integer value, for the number of nodes to be fetched (limits appears to be 999) and `:replies`, with a boolean value, to pass whether you want node replies to be included in the fetch.
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  Function returns a graph (not a list!) of UrbitEx.Node structs, according to count requested.
  You can convert the graph to a list with `UrbitEx.Graph.to_list/1`
  """

  def fetch_newest(session, resource, opts \\ []), do:
    fetch_siblings(session, resource, "", :newest, opts)

  @doc """
  Fetches oldest nodes from a channel.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, and an options keyword list (see above).
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  """

  def fetch_oldest(session, resource, opts \\ []),
    do: fetch_siblings(session, resource, "", :newest, opts)

  @doc """
  Fetches nodes from a channel which are older than a given index.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct,
  an index string  (passed index can have a "/" or not, doesn't matter) and an options keyword list (see above).
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  """

  def fetch_older_than(session, resource, index, opts \\ []),
    do: fetch_siblings(session, resource, index, :older, opts)

  @doc """
  Fetches nodes from a channel which are younger than a given index.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct,
  an index string  (passed index can have a "/" or not, doesn't matter) and an options keyword list (see above).
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  """

  def fetch_younger_than(session, resource, index, opts \\ []),
    do: fetch_siblings(session, resource, index, :younger, opts)


  def fetch_siblings(session, resource, index, type, opts) do
    mode = if opts[:replies], do: "kith", else: "lone"
    count = opts[:count] || 25
    endpoint =
      "/~/scry/graph-store/graph/#{resource.ship}/#{resource.name}/node/siblings/#{type}/#{mode}/#{count}#{Utils.break_index(index)}.json"
    scry(session.url <> endpoint, session.cookie)
  end

  @doc """
  Fetches nodes from a channel which are older than a given index.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, two index strings, start and finish, and an options keyword list (see above).
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  """

  def fetch_subset(session, resource, start_index, end_index, opts \\ []) do
    endin = Utils.break_index(end_index)
    startin = Utils.break_index(start_index)
    mode = if opts[:replies], do: "kith", else: "lone"

    endpoint =
      "/~/scry/graph-store/graph/#{resource.ship}/#{resource.name}/subset/#{mode}#{startin}#{endin}.json"
    scry(session.url <> endpoint, session.cookie)
  end

  @doc """
    Fetches children of a node.
    Takes a Session struct, a Resource struct, the parent index you want to scry, and optional start and end indexes if you want to specify a range for children to be fetched. Also takes an optional options keyword list (see above).
    If passed an empty parent_index it will scry the root node (i.e. the channel itself).
  """

  def fetch_children(session, resource, parent_index, start_index \\ "/", end_index \\ "/", opts \\ []) do
    mode = if opts[:replies], do: "kith", else: "lone"
    parentin = Utils.break_index(parent_index)
    start = Utils.break_index(start_index)
    till = Utils.break_index(end_index)
    endpoint =
      "/~/scry/graph-store/graph/#{resource.ship}/#{resource.name}/node/children/#{mode}/#{start}#{till}#{parentin}.json"
    scry(session.url <> endpoint, session.cookie)
  end

  @doc """
    Fetches a single node from a channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, a node index and an options keyword list (see above).
    GET requests trigger no SSE events.
    Eyre returns a 200 response.
  """
  def fetch_node(session, resource, index, opts \\ []) do
    mode = if opts[:replies], do: "kith", else: "lone"
    endpoint =
      "/~/scry/graph-store/graph/#{resource.ship}/#{resource.name}/node/index/#{mode}#{Utils.break_index(index)}.json"
    scry(session.url <> endpoint, session.cookie)
  end

  defp scry(endpoint, cookie) do
    case Airlock.get(endpoint, cookie) do
      {:ok, res} ->
        case Jason.decode(res.body) do
          {:ok, b} -> {:ok, b["graph-update"]["add-nodes"]["nodes"]}
          {:error, reason} -> {:error, reason}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
    Checks if a node exists in a given channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct and a node index.
    GET requests trigger no SSE events.
    Eyre returns a 200 response.
  """

  def exists?(session, resource, index) do
    endpoint =
      "/~/scry/graph-store/graph/#{resource.ship}/#{resource.name}/node/exists#{Utils.break_index(index)}.json"

    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    UrbitEx.Utils.eyre_boolean?(res.status_code)
  end

  @doc """
  Fetches the whole node graph from a channel.
  Takes an UrbitEx.Session struct and an UrbitEx.Resource struct.
  This is the endpoint Landscape uses to render Notebooks and Collections.
  You can run it on a Chat but it'll timeout with big ones (over 999 nodes?).
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  Function returns a graph (not a list!) of UrbitEx.Node structs, according to count requested.
  You can convert the graph to a list with `UrbitEx.Graph.to_list/1`

  """

  def fetch_whole_graph(session, resource) do
    endpoint = "/~/scry/graph-store/graph/#{resource.ship}/#{resource.name}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    {:ok, b} = Jason.decode(res.body)
    b["graph-update"]["add-graph"]["graph"]
  end

  # TODO
  def fetch_archived_graph(session, resource) do
    endpoint = "/~/scry/graph-store/archive/#{resource.ship}/#{resource.name}.json"
    {:ok, res} = Airlock.get(session.url <> endpoint, session.cookie)
    {:ok, b} = Jason.decode(res.body)
    b["graph-update"]["add-graph"]["graph"]
  end

  @doc """
  Fetches the all channels which the ship is a member of.
  Takes an UrbitEx.Session struct.
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  Function returns a list of UrbitEx.Resource structs.
  You can convert the graph to a list with `UrbitEx.Graph.to_list/1`

  """

  def fetch_keys(session) do
    fetch_global_stuff(session, "keys")
    |> Enum.map(&Resource.new(&1["ship"], &1["name"]))
  end

  @doc """
  Fetches tags.
  Takes an UrbitEx.Session struct.
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  Not sure what this is about.
  """
  def fetch_tags(session), do: fetch_global_stuff(session, "tags")

  @doc """
  Fetches tag queries.
  Takes an UrbitEx.Session struct.
  GET requests trigger no SSE events.
  Eyre returns a 200 response.
  Not sure what this is about.
  """

  def fetch_tag_queries(session), do: fetch_global_stuff(session, "tag-queries")

  defp fetch_global_stuff(session, keyword) do
    endpoint = "/~/scry/graph-store/#{keyword}.json"
    case Airlock.get(session.url <> endpoint, session.cookie) do
      {:ok, res} ->
        case Jason.decode(res.body) do
          {:ok, b} -> b["graph-update"][keyword]
          {:error, reason} -> {:error, reason}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  # writing stuff

  def add_node(json, session) do
    endpoint = "/spider/graph-update-2/graph-add-nodes/graph-view-action.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  def await_add_nodes() do
    receive do
      {:add_nodes, resource, nodes} -> {:nodes_added, resource, nodes}
    end
  end

  def await_new_members() do
    receive do
      {:add_members, resource, members} -> {:members_added, resource, members}
    end
  end

  @doc """
    Send message to a chat channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, a message string,
    and an optional custom list of token maps.
    Graph Store posts tokens can be `text`, `mention`, `url`, `code` or `reference`.
    In elixir a valid content list would look like `[%{text: title}, %{url: "https://urbitasia.com"}, %{mention: "~mirtyl-wacdec"}]`
    If no custom tokens are given, the function uses the default tokenizer used by Landscape.
    A custom tokenizer can be used to format text for custom clients without need for a custom backend.
    Triggers one `graph-update` event (the message itself).
    Eyre returns a 200 response.
  """
  def send_message(session, resource, message, custom \\ nil) do
    GraphStore.send_message(session.ship, resource, message, custom)
    |> add_node(session)
  end

  @doc """
    Posts a message to a group feed.
    Alias of `send_message/4`.
  """

  def post_to_group_feed(session, resource, message, custom \\ nil) do
    send_message(session, resource, message, custom)
  end

  @doc """
    Posts a reply to a post in a feed channel.
    Takes a ession struct, a Resource struct, a message string, an index string of the node to reply to,
    and an optional custom list of token maps.
  """
  def reply_to_feed_post(session, resource, index, message, custom \\ nil) do
    GraphStore.reply_to_feed_post(session.ship, resource, index, message, custom)
    |> add_node(session)

  end

  @doc """
    Adds a link to a Collection channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, a text string and a url string.
    Triggers one `graph-update` event (the link itself).
    Eyre returns a 200 response.
  """
  def add_collection_link(session, resource, text, url) do
    GraphStore.add_collection_link(session.ship, resource, text, url)
    |> add_node(session)
  end

  @doc """
    Adds a post to a Notebook channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, a title string,
    a text string, and an optional custom list of token maps.
    Graph Store posts tokens can be `text`, `mention`, `url`, `code` or `reference`.
    In elixir a valid content list would look like `[%{text: title}, %{url: "https://urbitasia.com"}, %{mention: "~mirtyl-wacdec"}]`
    If no custom tokens are given, the function uses the default tokenizer used by Landscape.
    Landscape's notebook post tokenizer renders the first text map as the title, the second as the post body.
    A custom tokenizer can be used to format text for custom clients without need for a custom backend.
    Triggers one `graph-update` event (the post itself).
    Eyre returns a 200 response.
  """

  def add_post(session, resource, title, text, custom \\ nil) do
    endpoint = "/spider/graph-update-2/graph-add-nodes/graph-view-action.json"
    json = GraphStore.add_notebook_post(session.ship, resource, title, text, custom)
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
  Adds a comment to a Notebook post or a Collection link.
  Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, an index string,
  a text string and an optional custom token list. See docs on `add_post` function above for notes on
  how custom token lists can be useful.
  Triggers one `graph-update` event (the comment itself).
  Eyre returns a 200 response.
  """

  def add_comment(session, resource, node, text, custom \\ nil) do
    endpoint = "/spider/graph-update-2/graph-add-nodes/graph-view-action.json"
    json = GraphStore.add_comment(session.ship, resource, node.post.index, text, custom)
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
    Edits a post in a Notebook channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct,
    an UrbitEx.Node struct of the post you want to edit (the larger node, not the posts revision container node),
    a title string, a text string, and an optional custom list of token maps (see above).
    Triggers one `graph-update` event (the post itself).
    Eyre returns a 200 response.
  """

  def edit_post(session, resource, node, title, text, custom \\ nil) do
    [post, _comments] = node.children
    new_index = increment_index(post)
    json = GraphStore.edit_post(session.ship, resource, new_index, title, text, custom)
    endpoint = "/spider/graph-update-2/graph-add-nodes/graph-view-action.json"
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  @doc """
    Edits a comment in a Notebook or Link channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct, an UrbitEx.Node struct of the comment (the one you want to edit),
    a title string, a text string, and an optional custom list of token maps (see above).
    Triggers one `graph-update` event (the post itself).
    Eyre returns a 200 response.
  """

  def edit_comment(session, resource, node, text, custom \\ nil) do
    new_index = increment_index(node)
    endpoint = "/spider/graph-update-2/graph-add-nodes/graph-view-action.json"
    json = GraphStore.edit_comment(session.ship, resource, new_index, text, custom)
    Airlock.post(session.url <> endpoint, json, session.cookie)
  end

  # pass the comment revision container node
  def increment_index(node) do
    last_revision = node.children |> Enum.max_by(& &1.post.index)
    last_index = last_revision.post.index
    [lastnum] = Regex.run(~r(\d+$), last_index)
    lastnum = String.to_integer(lastnum)
    _new_index = last_index |> String.replace(~r(\/\d$), "/#{lastnum + 1}")
  end

  @doc """
    Deletes nodes in any channel.
    Takes an UrbitEx.Session struct, an UrbitEx.Resource struct and list of index strings.
    Index strings must have a preceding slash, i.e. `"/170141184505071972989094238161226170368"`
    Revisable nodes (notebook posts and comments) must delete the revision container and the first child.
    Triggers one `graph-update` event.
    Eyre returns a 204 response.
  """

  def delete_nodes(session, channel, resource, indices) do
    json = GraphStore.remove_node(resource, indices)
    body = Actions.poke(session.ship, "graph-push-hook", "graph-update-2", json)
    API.wrap_put(session, channel, [body])
  end
end
