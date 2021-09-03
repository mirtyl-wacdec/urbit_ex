defmodule UrbitEx.GraphStore do
  alias UrbitEx.Utils
  alias UrbitEx.{Resource}

  # this works for both groups and channels, "leave" is different for some reason
  def join_resource(resource) do
    %{
      join: %{
        resource: resource,
        ship: resource.ship
      }
    }
  end

  def leave_channel(resource) do
    %{
      leave: %{
        resource: resource
      }
    }
  end

  def accept_invite() do
  end

  def create_channel(ship, group, title, name, description, type, association, invitees \\ []) do
    # TODO `Utils.channel_name(name) apes Landscape practice but you might not want that
    # channel_name = if String.starts_with?(name, "dm"), do: name, else: Utils.channel_name(name)

    %{
      create: %{
        title: title,
        description: description,
        module: type,
        mark: "graph-validator-#{type}",
        resource:
          Resource.new(
            ship,
            name
          ),
        associated: branch_channel(association, group, invitees)
      }
    }
  end

  defp branch_channel(:group, group, _), do: %{group: group}
  defp branch_channel(:private, _, invitees), do: %{policy: %{invite: %{pending: invitees}}}
  defp branch_channel(:public, _, _), do: %{policy: %{open: %{banRanks: [], banned: []}}}

  def delete_channel(resource), do: %{delete: %{resource: resource}}

  def enable_group_feed(resource, permission) do
    %{
      "create-group-feed": %{
        resource: resource,
        vip: permission
      }
    }
  end

  def disable_group_feed(resource) do
    %{
      "disable-group-feed": %{
        resource: resource
      }
    }
  end

  def send_dm(author, target_ud, message, custom) do
    contents = if custom, do: custom, else: Utils.tokenize(message)
    resource = Resource.new(author, "dm-inbox")

    contents
    |> build_post(author, "/#{target_ud}")
    |> build_node()
    |> wrap_node(resource)
  end

  # feed posts use this too
  def send_message(author, resource, message, custom) do
    contents = if custom, do: custom, else: Utils.tokenize(message)

    contents
    |> build_post(author)
    |> build_node()
    |> wrap_node(resource)
  end

  def reply_to_feed_post(author, resource, parent_index, message, custom) do
    contents = if custom, do: custom, else: Utils.tokenize(message)

    contents
    |> build_post(author, parent_index)
    |> build_node()
    |> wrap_node(resource)
  end

  def add_collection_link(author, resource, text, url) do
    build_collection_link(text, url)
    |> build_post(author)
    |> build_node()
    |> wrap_node(resource)
  end

  def add_notebook_post(author, resource, title, text, custom) do
    contents = if custom, do: custom, else: build_notebook_post(title, text)
    container = build_post([], author)
    post_wrapper = build_post([], author) |> Map.put(:index, "#{container.index}/1")
    comments_wrapper = build_post([], author) |> Map.put(:index, "#{container.index}/2")
    post = build_post(contents, author) |> Map.put(:index, "#{container.index}/1/1")
    post_node = build_child_node(post, 1)
    post_wrapper_node = build_child_node(post_wrapper, 1, post_node)
    comments_wrapper_node = build_child_node(comments_wrapper, 2)

    _container_node =
      build_node(container, Map.merge(post_wrapper_node, comments_wrapper_node))
      |> wrap_node(resource)
  end

  def edit_post(author, resource, new_index, title, text, custom) do
    contents = if custom, do: custom, else: build_notebook_post(title, text)
    post = build_post(contents, author) |> Map.put(:index, new_index)

    _post_node =
      build_node(post)
      |> wrap_node(resource)
  end

  # to delete graphs with wrappers you need to specify all indexes
  def add_comment(author, resource, index, text, custom) do
    contents = if custom, do: custom, else: Utils.tokenize(text)
    comment_wrapper = build_post([], author, "#{index}/2")

    comment =
      build_post(contents, author)
      |> Map.put(:index, "#{comment_wrapper.index}/1")

    comment_node = build_child_node(comment, 1)

    build_node(comment_wrapper, comment_node)
    |> wrap_node(resource)
  end

  def edit_comment(author, resource, new_index, text, custom) do
    contents = if custom, do: custom, else: Utils.tokenize(text)
    post = build_post(contents, author) |> Map.put(:index, new_index)

    _post_node =
      build_node(post)
      |> wrap_node(resource)
  end

  defp build_collection_link(text, url) do
    [%{text: text}, %{url: url}]
  end

  defp build_notebook_post(title, body), do: [%{text: title} | Utils.tokenize(body)]

  defp build_post(contents, author, parent_index \\ "") do
    timestamp = System.os_time(:millisecond)
    index = parent_index <> "/#{Utils.calculate_index(timestamp)}"
    # need some logic here to check if already there
    author = "~#{author}"

    %UrbitEx.Post{
      author: author,
      contents: contents,
      "time-sent": timestamp,
      index: index
    }
  end

  defp build_node(post, children \\ nil) do
    %{post.index => %{post: post, children: children}}
  end

  defp build_child_node(post, index, children \\ nil) do
    %{index => %{post: post, children: children}}
  end

  defp wrap_node(node, resource) do
    %{
      "add-nodes": %{
        resource: resource,
        nodes: node
      }
    }
  end

  # comments remove two indices, main and main/1

  def remove_node(resource, indices) do
    %{
      "remove-posts": %{
        resource: %{
          name: resource.name,
          ship: resource.ship
        },
        indices: indices
      }
    }
  end

  # graph-validator-chat, graph-validator-post
  def add_graph(resource, mark) do
    %{
      "add-graph": %{
        graph: %{
          resource: resource,
          mark: mark,
          overwrite: true
        }
      }
    }
  end


  def add_group(resource) do
    %{
      groupUpdate: %{
        addGroup: %{
          policy: %{open: %{banned: [], banRanks: []}},
          resource: resource,
          hidden: false
        }
      }
    }
  end
end
