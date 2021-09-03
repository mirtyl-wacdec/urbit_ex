defmodule UrbitEx.HarkStore do
  alias UrbitEx.{Resource, Utils}
  # "app":"hark-group-hook","mark":"hark-group-hook-action"
  def set_group_notifications(action, resource) do
    %{action => Resource.to_url(resource)}
  end

  def set_channel_notifications(action, resource) do
    %{
      action => %{
        graph: Resource.to_url(resource),
        index: "/"
      }
    }
  end

  def mark_group_as_read(group) do
    %{"read-group": Resource.to_url(group)}
  end

  def mark_channel_as_read(group, channel) do
    %{
      "read-count": %{
        graph: %{
          description: "message",
          graph: Resource.to_url(channel),
          group: Resource.to_url(group),
          index: "/"
        }
      }
    }
  end

  def mark_node_as_read(group, channel, node_index, channel_type) do
    description =
      case channel_type do
        :link -> :link
        :publish -> :note
        :chat -> :mention
      end

    %{
      "read-note": %{
        index: %{
          graph: %{
            description: description,
            graph: Resource.to_url(channel),
            group: Resource.to_url(group),
            index: "/",
            module: channel_type
          },
          time: Utils.break_index(node_index)
        }
      }
    }
  end

  def mark_whole_node_as_read(group, channel, node_index, channel_type) do
    description =
      case channel_type do
        :link -> :link
        :publish -> :note
        :chat -> :mention
      end

    %{
      "read-each": %{
        index: %{
          graph: %{
            description: description,
            graph: Resource.to_url(channel),
            group: Resource.to_url(group),
            index: "/",
            module: channel_type
          }
        },
        target: node_index
      }
    }
  end

  # TODO
  def read_all(), do: %{"read-all": nil}

  def see(_node), do: %{seen: nil}

  ## global
  # "app":"hark-store","mark":"hark-action",
  def set_dnd(boolean), do: %{"set-dnd": boolean}
  # "app":"hark-graph-hook","mark":"hark-graph-hook-action",
  def set_watch_replies(boolean), do: %{"set-watch-on-self": boolean}
  # "app":"hark-graph-hook","mark":"hark-graph-hook-action",
  def set_watch_mentions(boolean), do: %{"set-mentions": boolean}
end
