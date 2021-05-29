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

  def leave_group(resource) do
    %{
      leave: %{
        ship: resource.ship,
        name: resource.name
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

  def create_group(name, title, description, "open", opts) do
    banned_ranks = Keyword.get(opts, :banned_ranks) || []
    banned_ships = Keyword.get(opts, :banned_ships) || []
    banned_ranks = Enum.map(banned_ranks, &Utils.add_tilde/1)
    banned_ships = Enum.map(banned_ships, &Utils.add_tilde/1)

    %{
      create: %{
        name: name |> Utils.group_name(),
        title: title,
        description: description,
        policy: %{
          open: %{
            banRanks: banned_ranks,
            banned: banned_ships
          }
        }
      }
    }
  end

  def create_group(name, title, description, "invite", opts) do
    invitees = Keyword.get(opts, :invitees) || []
    invitees = Enum.map(invitees, &Utils.add_tilde/1)

    %{
      create: %{
        name: name |> String.downcase() |> String.replace(" ", "-"),
        title: title,
        description: description,
        policy: %{
          invite: %{
            pending: invitees
          }
        }
      }
    }
  end

  def delete_group(resource) do
    %{
      remove: %{
        ship: resource.ship,
        name: resource.name
      }
    }
  end

  def change_group_policy(resource, type) do
    %{
      changePolicy: %{
        diff: %{
          replace: policy_change(type)
        },
        resource: resource
      }
    }
  end

  defp policy_change(:to_public), do: %{open: %{banned: [], banRanks: []}}
  defp policy_change(:to_private), do: %{invite: %{pending: []}}

  def ban_from_group(resource, type, targets) do
    %{
      changePolicy: %{
        resource: resource,
        diff: %{
          open: banned_target(type, targets)
        }
      }
    }
  end

  defp banned_target(:ships, targets), do: %{banShips: targets}
  defp banned_target(:ranks, targets), do: %{banRanks: targets}

  def invite_to_group(resource, invitees, message) do
    %{
      invite: %{
        ships: invitees,
        description: message,
        resource: resource
      }
    }
  end

  def kick_from_group(group, ships) do
    %{
      removeMembers: %{
        resource: group,
        ships: ships
      }
    }
  end

  def accept_invite() do
  end

  def create_channel(ship, group, title, name, description, type, association, invitees \\ []) do
    channel_name = if String.starts_with?(name, "dm"), do: name, else: Utils.channel_name(name)

    %{
      create: %{
        title: title,
        description: description,
        module: type,
        mark: "graph-validator-#{type}",
        resource:
          Resource.new(
            ship,
            channel_name
          ),
        associated: branch_channel(association, group, invitees)
      }
    }
  end

  defp branch_channel(:group, group, _), do: %{group: group}
  defp branch_channel(:private, _, invitees), do: %{policy: %{invite: %{pending: invitees}}}

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

  # feed posts use this too
  def send_message(author, resource, message, custom) do
    contents = if custom, do: custom, else: Utils.tokenize(message)

    contents
    |> build_post(author)
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
    comment_wrapper = build_post([], author)
    comment_wrapper = Map.put(comment_wrapper, :index, "#{index}/2#{comment_wrapper.index}")

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

  defp build_post(contents, author) do
    timestamp = System.os_time(:millisecond)
    index = "/#{Utils.calculate_index(timestamp)}"
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
end
