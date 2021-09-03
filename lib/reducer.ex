defmodule UrbitEx.Reducer do
  alias UrbitEx.{
    Channel,
    Utils,
    Resource,
    Graph,
    GroupGraph,
    Notification,
    Unread
  }

  @moduledoc """
    Module containing the default functions to handle SSE events sent from the Urbit ship.
    Some events are sent to the Session process to keep the state of the session, e.g. lists of groups, channels, unreads, notifications, etc.
    All events are sent to subscribers of the channel calling this reducer module, either in parsed or raw form.
  """

  @doc """
    Single public function of the module, called by the Channel process. It keeps track of sse and action id, sends errors to the channel subscribes,
    and most importantly parses and routes json events to use in client apps using this library.
  """

  def default_reducer(event) do
    case event do
      %{"json" => json, "id" => action_id} ->
        handle_id(action_id)
        handle_json(json)

      %{"ok" => _ok} = data ->
        # IO.inspect(data, label: :ack)
        nil

      %{"err" => err} ->
        IO.inspect(event, label: :error)
        send(self(), {:send, {:error, err}})

      %{"response" => response} ->
        # IO.inspect(event, label: :response)
        handle_response(response)


      other ->
        IO.inspect(other, label: :other)
    end
  end

  defp handle_id(id), do: Channel.save_action(id)

  defp handle_response("quit") do
    :quit
  end

  defp handle_response("diff") do
    :diff
  end

  defp handle_json(json) do
    case json do
      %{"dm-hook-action" => data} ->
        handle_dm(data)

      %{"invite-update" => data} ->
        handle_invite(data)

      %{"metadata-update" => data} ->
        handle_metadata(data)

      %{"metadata-hook-update" => data} ->
        # used for previews mostly
        handle_metadata_hook(data)

      %{"launch-update" => data} ->
        handle_launch(data)

      %{"location" => data} ->
        handle_location(data)

      %{"group-view-update" => data} ->
        handle_group_view(data)

      %{"graph-update" => data} ->
        handle_graph(data)

      %{"groupUpdate" => data} ->
        handle_group(data)

      %{"contact-update" => data} ->
        handle_contact(data)

      %{"s3-update" => data} ->
        handle_s3(data)

      %{"harkUpdate" => data} ->
        handle_hark(data)

      %{"hark-graph-hook-update" => data} ->
        handle_hark_graph(data)

      %{"hark-group-hook-update" => data} ->
        handle_hark_group(data)

      %{"settings-event" => data} ->
        handle_settings_event(data)

      %{"hop" => _} = data ->
        handle_herm(data)

      %{"mor" => _} = data ->
        handle_herm(data)

      %{"lin" => _} = data ->
        handle_herm(data)

      data ->
        {:send, {:error, data}}
    end
  end

  defp handle_dm(data) do
    case data do
      %{"pendings" => list} -> send(self(), {:save, {:pending_dms, Enum.map(list, &Utils.add_tilde/1)}})
      %{"accept" => p} ->
        send(self(), {:send, {:dm_accepted, Utils.add_tilde(p)}})
        send(self(), {:remove, {:pending_dms, Utils.add_tilde(p)}})
      %{"decline" => p} ->
        send(self(), {:send, {:dm_declined, Utils.add_tilde(p)}})
        send(self(), {:remove, {:pending_dms, Utils.add_tilde(p)}})
      # DM setting
      %{"screen" => boolean} -> send(self(), {:send, {:dm_screen, boolean}})
      thing -> IO.inspect(thing, label: :dms_weird)
    end
  end

  defp handle_metadata(data) do
    case data do
      %{"associations" => graph} ->
        # g = UrbitEx.Metadata.process(graph)
        list = UrbitEx.Metadata.to_list(graph)
        send(self(),  {:save, {:metadata, list}})

      # for some reason a metadata change triggers two events
      %{"add" => metadata} ->
        send(self(), {:add_or_update, {:metadata, UrbitEx.Metadata.new(metadata)}})

      %{"remove" => metadata} ->
        r = Resource.from_url(metadata["resource"])
        g = Enum.find(UrbitEx.get.metadata, & &1.resource == r)
        send(self(), {:remove, {:metadata, g}})

      #when first joining a group ??
      %{"initial-group" => %{"associations" => _graph}} ->
        nil

      other -> IO.inspect(other, label: :other_metadata)
    end
  end

  defp handle_metadata_hook(data) do
    case data do
      %{"preview" => preview} ->
        send(self(), {:send, {:group_preview, preview}})
    end
  end

  defp handle_graph(data) do
    case data do
      # you can fetch those
      %{"keys" => keys} ->
        k = Enum.map(keys, & Resource.new(&1["ship"], &1["name"]))
        send(self(), {:save, {:keys, k}})
      %{"add-graph" => d} ->
        # this event also gives you the graph type as d["mark"]
       send(self(), {:add, {:keys, Resource.new(d["resource"]["ship"], d["resource"]["name"])}})
      %{"remove-graph" => d} ->
        send(self(),{:remove, {:keys, Resource.new(d["ship"], d["name"])}})
      %{"add-nodes" => datas} ->
        add_nodes(datas)
      %{"remove-posts" => data} ->
       send(self(),{:send,
         {:remove_posts, Resource.new(data["resource"]["ship"], data["resource"]["name"]),
          data["indices"]}})
      other ->
        IO.inspect(other, label: :graph_update_weird)
    end
  end

  defp add_nodes(data) do
    resource = Resource.new(data["resource"]["ship"], data["resource"]["name"])
    nodes = Graph.to_list(data["nodes"])
    send(self(), {:send, {:add_nodes, resource, nodes}})
  end


  defp handle_invite(data) do
    case data do
      # gets initial invites when you log in
      # initial invites are a map with 3 keys, "chat", "graph" or "group"
      # which can show an invite graph or an empty map.
      # dms show up as "graph" so go figure what "chat" does.
      %{"initial" => d} ->
        handle_initial_invites(d)

      %{"accepted" => d} ->
        inv = Enum.find(UrbitEx.get.invites, & &1.hash == d["uid"])
        send(self(), {:send, {:invite_accepted, inv}})
        send(self(), {:remove, {:invites, inv}})

      %{"decline" => d} ->
        inv = Enum.find(UrbitEx.get.invites, & &1.hash == d["uid"])
        send(self(), {:send, {:invite_declined, inv}})
        send(self(), {:remove, {:invites, inv}})

      %{"invite" => invite} ->
        inv = UrbitEx.Invite.new_incoming(invite)
        send(self(), {:add, {:invites, inv}})
    end
  end

  defp handle_initial_invites(data) do
    chat = data["chat"]
    graph = data["graph"]
    groups = data["groups"]
    chat_invites = UrbitEx.Invite.to_list(chat, "chat")
    group_invites = UrbitEx.Invite.to_list(groups, "groups")
    graph_invites = UrbitEx.Invite.to_list(graph, "graph")
    send(self(),{:save, {:invites, chat_invites ++ group_invites ++ graph_invites}})
  end

  defp handle_launch(data) do
    send(self(), {:send, {:launch, data}})
  end

  defp handle_location(data) do
    send(self(), {:send, {:location, data}})
  end

  # this is group joining
  defp handle_group_view(data) do
    case data do
      %{"initial" => graph} ->
        list = graph |> Map.keys |> Enum.map(& {UrbitEx.Resource.from_url(&1), graph[&1]["progress"]})
        send(self(), {:save, {:group_joins, list}})

      %{"progress" => %{"resource" => resource, "progress" => progress}} ->
        send(self(), {:send, {:join_group_progress, Resource.from_url(resource), progress}})

      %{"started" => %{"resource" => resource}} ->
        send(self(), {:send, {:join_group_started, Resource.from_url(resource)}})
      %{"hide" => resource} ->
        send(self(), {:remove, {:group_joins, Resource.from_url(resource)}})
      thing ->
        IO.inspect(thing, label: :groupjoin_weird)
    end
  end

  defp handle_group(data) do
    case data do
      %{"initial" => datas} ->
        groups = UrbitEx.GroupGraph.to_list(datas)
        send(self(), {:save, {:groups, groups}})

      %{"addMembers" => %{"resource" => resource, "ships" => ships}} ->
        r = Resource.new(resource["ship"], resource["name"])
        send(self(), {:update, {:groups, :add_members, r, ships}})


      %{"removeMembers" => %{"resource" => resource, "ships" => ships}} ->
        r = Resource.new(resource["ship"], resource["name"])
        send(self(), {:update, {:groups, :remove_members, r, ships}})

      # creating a group
      %{"addGroup" => %{"resource" => resource}} ->
        r = Resource.new(resource["ship"], resource["name"])
        send(self(), {:add, {:groups, GroupGraph.init(r)}})

      #leaving a group
      %{"removeGroup" => %{"resource" => resource}} ->
        r = Resource.new(resource["ship"], resource["name"])
        g = Enum.find(UrbitEx.get.groups, & &1.resource == r)
        send(self(), {:remove, {:groups, g}})

      %{"changePolicy" => %{"diff" => diff, "resource" => resource}} ->
        # "diff" => %{"replace" => %{"open" => %{"banRanks" => [], "banned" => []}}},
        send(self(), {:update, {:groups, :policy, Resource.new(resource["ship"], resource["name"]), diff}})

      %{"addTag" => tag} ->
        send(self(), {:update, {:groups, :tags, Resource.new(tag["resource"]["ship"], tag["resource"]["name"]), tag["tag"]["tag"], tag["ships"]}})
      %{"removeTag" => tag} ->
        send(self(), {:update, {:groups, :tags, Resource.new(tag["resource"]["ship"], tag["resource"]["name"]), tag["tag"]["tag"], tag["ships"]}})
      # triggers on group join and at weird intervals
      %{"initialGroup" => data} ->
         group = GroupGraph.from_map(data["group"], data["resource"])
         send(self(), {:add_or_update, {:groups, group}})
      _ ->
        IO.inspect(data, label: :groupupdate_weird)
    end
  end

  defp handle_contact(data) do
    case data do
      %{"initial" => datas} ->
        # contacts = UrbitEx.Contact.to_list(datas)
        # contacts might be easier to handle as a graph than as a list. Easier to query.
        # Session.save_contacts(UrbitEx.Contact.to_list(datas["rolodex"]))
        send(self(), {:save, {:contacts, datas["rolodex"]}})
      %{"edit" => edit} ->
        [key] = edit["edit-field"] |> Map.keys
        value = edit["edit-field"][key]
        send(self(), {:add_or_update, {:contacts, Utils.add_tilde(edit["ship"]), key, value}})
      _ ->
        IO.inspect(data, label: :contacts_weird)
    end
  end

  defp handle_s3(data) do
    # login event be like
    # %{
    #   "credentials" => %{
    #     "accessKeyId" => "",
    #     "endpoint" => "",
    #     "secretAccessKey" => ""
    #   }}
    # s3_update: %{"configuration" => %{"buckets" => [], "currentBucket" => ""}}
    case data do
      %{"credentials" => map} ->
        struct = %{UrbitEx.get.s3 | login: map["accessKeyId"], password: map["secretAccessKey"], endpoint: map["endpoint"]}
        send(self(), {:update, {:s3, struct}})

      %{"configuration" => map} ->
        struct = %{UrbitEx.get.s3 | buckets: map["buckets"], current_bucket: map["currentBucket"]}
        send(self(), {:update, {:s3, struct}})

      %{"setEndpoint" => string} ->
        send(self(), {:update, {:s3, :endpoint, string}})
      %{"setAccessKeyId" => string} ->
        send(self(), {:update, {:s3, :login, string}})
      %{"setSecretAccessKey" => string} ->
        send(self(), {:update, {:s3, :password, string}})
      %{"addBucket" => bucket} ->
        send(self(), {:update, {:s3, :add_bucket, bucket}})
      %{"removeBucket" => bucket} ->
        send(self(), {:update, {:s3, :remove_bucket, bucket}})
      %{"setCurrentBucket" => bucket} ->
        send(self(), {:update, {:s3, :current_bucket, bucket}})
      d ->
        IO.inspect(d, label: :s3_weird)
    end
  end

  defp handle_hark(data) do
    # a new unread on a chat or post channel triggers an "unread-count" and "seen-index" events together"

    data["more"] |> Enum.each(fn
      %{"set-dnd" => dnd} -> dnd
      ## unreads
      %{"unreads" => unreads} ->
        tuple =  {:unread, unreads |> Enum.map(&Unread.new/1)}
        send(self(), {:save, tuple})
      %{"unread-count" => index} ->
        tuple = {:unread, :add_count, Resource.from_url(index["index"]["graph"]["graph"]), index["index"]["graph"]["index"], DateTime.from_unix!(index["last"], :millisecond)}
        send(self(), {:update, tuple})
      %{"read-count" => index} ->
        tuple = {:unread, :clear_count, Resource.from_url(index["graph"]["graph"]), index["graph"]["index"]}
        send(self(), {:update, tuple})
      %{"unread-each" => index} ->
        tuple = {:unread, :add_each, Resource.from_url(index["index"]["graph"]["graph"]), index["target"], DateTime.from_unix!(index["last"], :millisecond)}
        send(self(), {:update, tuple})
      %{"read-each" => index} ->
        tuple = {:unread, :clear_each, Resource.from_url(index["index"]["graph"]["graph"]), index["target"]}
        send(self(), {:update, tuple})
      %{"seen-index" => index} ->
        send(self(), {:send, {:index_seen, Resource.from_url(index["index"]["graph"]["graph"]), index["index"]["graph"]["index"], index["time"]}})
        ## notifications
      %{"timebox" => timebox} ->
          notifs = timebox["notifications"]
          |> Enum.map(&Notification.new/1)
          notes = %{
            mentions: Enum.filter(notifs, & &1.type == :mention),
            messages: Enum.filter(notifs, & &1.type == :message),
            notes: Enum.filter(notifs, & &1.type == :note),
            posts: Enum.filter(notifs, & &1.type == :post),
            links: Enum.filter(notifs, & &1.type == :link),
            comments: Enum.filter(notifs, & &1.type == :comment),
            joined: Enum.filter(notifs, & &1.type == :"add-members"),
            left: Enum.filter(notifs, & &1.type == :"remove-members"),
          }
          tuple = {:notifications, notes}
          send(self(),{:save, tuple})
      %{"added" => notif} ->
        #sent in cumulative batches, per type/channel
        tuple = {:notifications, Notification.new(notif)}
        send(self(), {:add_or_update, tuple})
      %{"note-read" => index} ->
        #time here is an index (with dots and shit) fors ome reason
        time = Utils.parse_index(index["time"])
        tuple =  if index["index"]["graph"] do 
          {:notifications, String.to_atom(index["index"]["graph"]["description"]), Resource.from_url(index["index"]["graph"]["graph"]), index["index"]["graph"]["index"], time}
        else 
          {:notifications, String.to_atom(index["index"]["group"]["description"]), Resource.from_url(index["index"]["group"]["group"]), nil, time}
        end
        send(self(), {:remove, tuple})
      %{"remove-graph" => resource_url} ->
        send(self(), {:send, {:hark_graph_removed, Resource.from_url(resource_url)}})
      %{"listen" => resource_url} ->
        send(self(), {:send, {:hark_listening, Resource.from_url(resource_url)}})
      thing -> IO.inspect(thing, label: :hark_weird)
    end)
  end

  defp handle_hark_graph(data) do
    # initial gives you a map with 3 keys,
    # %{mentions: true, whatOnSelf: "true", watching: [%{graph: :resource_url}, index: "/"]}
    case data do
      %{"initial" => d} ->
        {:send, {:hark_graph_initial, d}}
      %{"listen" => graph} ->
        {:send, {:hark_graph_listen, Resource.from_url(graph["graph"]), graph["index"]}}
      %{"ignore" => graph} ->
        {:send, {:hark_graph_ignore, Resource.from_url(graph["graph"]), graph["index"]}}
      other -> IO.inspect(other, label: :hark_graph_weird)
    end
  end

  defp handle_hark_group(data) do
    case data do
      %{"initial" => d} -> {:send, {:hark_group_initial, d}}
      thing -> IO.inspect(thing, label: :hark_group_weird)
    end
  end

  defp handle_settings_event(data) do
    case data do
      %{"put-bucket" => bucket} ->
        tuple = {:settings_bucket_added, bucket["bucket-key"], bucket["bucket"]}
        # send(self(), {:save, tuple})
        send(self(),{:send, tuple})
      %{"del-bucket" => bucket} ->
        tuple = {:settings_bucket_deleted, bucket["bucket-key"]}
        # send(self(), {:save, tuple})
        send(self(),{:send, tuple})
      %{"put-entry" => entry} ->
        tuple = {:settings_entry_added, entry["bucket-key"], entry["entry-key"], entry["value"]}
        # send(self(), {:save, tuple})
        send(self(),{:send, tuple})
      %{"del-entry" => entry} ->
        tuple = {:settings_entry_deleted, entry["bucket-key"], entry["entry-key"]}
        send(self(), {:send, tuple})
      thing -> IO.inspect(thing, label: :settings_weird)
    end
  end

  defp handle_herm(data) do
    case data do
      %{"hop" => number} ->
        send(self(), {:send, {:current_prompt_length, number}})
      %{"mor" => _boolean} ->
        #no idea what this does. usually "true"
        nil
      %{"lin" => lin} ->
        tuple = {:current_line, Enum.join(lin, "")}
        send(self(), {:send, tuple})
      thing -> IO.inspect(thing, label: :herm_weird)
    end
  end

end
