defmodule UrbitEx.Handler do
  alias UrbitEx.{API, Utils, Resource, Graph, Node, Post, Groups}

  @moduledoc """
    Module containing functions to handle SSE events sent from the Urbit ship.
  """

  def general(json) do
    case json do
      %{"metadata-update" => data} ->
        metadata_update(data)

      %{"invite-update" => data} ->
        invite_update(data)

      %{"launch-update" => data} ->
        launch_update(data)

      %{"location" => data} ->
        location(data)

      %{"group-view-update" => data} ->
        group_view_update(data)

      %{"graph-update" => data} ->
        graph_update(data)

      %{"groupUpdate" => data} ->
        group_update(data)

      %{"contact-update" => data} ->
        contact_update(data)

      %{"s3-update" => data} ->
        s3_update(data)

      %{"harkUpdate" => data} ->
        hark_update(data)

      %{"hark-graph-hook-update" => data} ->
        hark_graph_hook_update(data)

      %{"hark-group-hook-update" => data} ->
        hark_group_hook_update(data)

      %{"settings-event" => data} ->
        "hi"

      data ->
        require IEx
        IEx.pry()
        IO.inspect(data, label: :wtf)
    end
  end

  defp metadata_update(data) do
    # IO.inspects(data)
  end

  defp graph_update(data) do
    case data do
      %{"keys" => keys} -> keys
      %{"add-nodes" => datas} -> add_graphs(datas)
      _ -> IO.inspect(data, label: :graph_update)
    end
  end

  defp add_graphs(data) do
    resource = Resource.new(data["resource"]["ship"], data["resource"]["name"])
    nodes = Graph.to_list(data["nodes"])
    our = UrbitEx.get_state().ship |> Utils.add_tilde()

    for node <- nodes, do: if(node.post.author != our, do: handle_post(resource, node.post))
  end

  defp handle_post(resource, post) do
    text =
      Enum.map(post.contents, &Map.values/1)
      |> List.flatten()
      |> Enum.join("-")
      |> String.downcase()
      |> IO.inspect()

    if String.contains?(text, "elixir") do
      s = UrbitEx.get_state()
      API.Graph.send_message(s, resource, "Elixir is awesome, man")
    end
  end

  defp invite_update(data) do
    IO.inspect(data, label: :invite_update)

    case data do
      # gets initial invites when you log in
      # initial invites are a map with 3 keys, "chat", "graph" or "group"
      # which can show an invite graph or an empty map.
      # dms show up as "graph" so go figure what "chat" does.
      %{"initial" => datas} -> handle_initial_invites(datas)
    end
  end

  defp handle_initial_invites(data) do
    %{"chat" => chat, "graph" => graph, "groups" => groups} = data
    chat_invites = UrbitEx.Invite.to_list(chat)
    group_invites = UrbitEx.Invite.to_list(graph)
    graph_invites = UrbitEx.Invite.to_list(groups)
  end

  # %{
  #   "initial" => %{
  #     "firstTime" => true,
  #     "tileOrdering" => ["weather", "clock", "term"],
  #     "tiles" => %{
  #       "clock" => %{"isShown" => true, "type" => %{"custom" => nil}},
  #       "term" => %{
  #         "isShown" => true,
  #         "type" => %{
  #           "basic" => %{
  #             "iconUrl" => "/~landscape/img/term.png",
  #             "linkedUrl" => "/~term",
  #             "title" => "Terminal"
  #           }
  #         }
  #       },
  #       "weather" => %{"isShown" => true, "type" => %{"custom" => nil}}
  #     }
  #   }
  # }
  defp launch_update(data) do
    IO.inspect(data, label: :launch_update)
  end

  defp location(data) do
    IO.inspect(data, label: :location)
    # this just gives the string you input in landscape lol
  end

  defp group_view_update(data) do
    case data do
      %{"initial" => data} -> IO.inspect(data, label: :gvu_initial)
      %{"started" => data} -> IO.inspect(data, label: :gvu_started)
      _ -> IO.inspect(data, label: :gvu_?)
    end
  end

  defp group_update(data) do
    # shows groups you're a member of, good to display in a client
    case data do
      %{"initial" => datas} ->
        UrbitEx.GroupGraph.to_list(datas) |> IO.inspect()

      _ ->
        IO.inspect(data, label: :groupupdate)
    end
  end

  defp contact_update(data) do
    # wtf is this about
    # %{
    #   "~talbur-tastes" => %{
    #     "avatar" => "https://files.catbox.moe/27yfkk.png",
    #     "bio" => "",
    #     "color" => "0xff.ffff",
    #     "cover" => "",
    #     "groups" => [],
    #     "last-updated" => 1616869406838,
    #     "nickname" => "ScalemaiL",
    #     "status" => "Hello World!"
    #   },
    # %{"is-public" => false,
    #  "rolodex" => %{} #graph of ships
    # }
    # IO.inspect(data, label: :contact_update)
  end

  defp s3_update(data) do
    # login event be like
    # %{
    #   "credentials" => %{
    #     "accessKeyId" => "",
    #     "endpoint" => "",
    #     "secretAccessKey" => ""
    #   }}
    # s3_update: %{"configuration" => %{"buckets" => [], "currentBucket" => ""}}
    case data do
      %{"credentials" => datas} -> IO.inspect(data)
      %{"configuration" => datas} -> IO.inspect(data)
    end
  end

  defp hark_update(data) do
    # IO.inspect(data, label: :hark_update)
  end

  defp hark_graph_hook_update(data) do
    # IO.inspect(data, label: :hark_graph_hook_update)
  end

  defp hark_group_hook_update(data) do
    # IO.inspect(data, label: :hark_group_hook_update)
  end

  def groupjoin(json) do
    case json do
      %{"group-view-update" => %{"started" => data}} ->
        groupjoin_started(data)

      %{"group-view-update" => %{"progress" => %{"progress" => progress, "resource" => resource}}} ->
        groupjoin_progress(progress, resource)

      %{"groupUpdate" => %{"initialGroup" => %{"group" => group, "resource" => resource}}} ->
        early_metadata(group, resource)

      %{"metadata-update" => %{"initial-group" => data}} ->
        complete_metadata(data)

      other ->
        IO.inspect(other)
    end
  end

  def groupjoin_started(data), do: IO.puts("Group Join request sent to #{data["resource"]}")

  def groupjoin_progress("start", resource), do: IO.puts("Join started to #{resource}")

  def groupjoin_progress("no-perms", resource),
    do: IO.puts("Can't join #{resource}, it's private")

  def groupjoin_progress("added", resource),
    do: IO.puts("Successfully joined #{resource}, fetching metadata")

  def groupjoin_progress("done", resource), do: IO.puts("Group join to #{resource} complete")

  def early_metadata(group, resource) do
    name = resource["name"]
    host = resource["ship"] |> Utils.add_tilde()
    admins = group["tags"]["admin"] |> Enum.map(&Utils.add_tilde/1) |> Enum.join(", ")
    members = group["members"] |> Enum.map(&Utils.add_tilde/1) |> Enum.join(", ")
    banned_ranks = group["policy"]["open"]["banRanks"] |> Enum.join(", ")
    banned_ships = group["policy"]["open"]["banned"] |> Enum.join(", ")
    hidden = group["hidden"]

    IO.puts("""
    Joined #{name} hosted by #{host}.
    Admins are #{admins}.
    Members are #{members}.
    The following ranks are banned #{banned_ranks}.
    The following ships are banned #{banned_ships}.
    """)
  end

  def complete_metadata(data) do
    IO.puts("lots of stuff")
  end

  def group_leave(json) do
  end

  def group_create(json) do
  end

  def group_delete(json) do
  end

  def handle_invite(json) do
  end
end
