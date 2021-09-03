defmodule UrbitEx.GroupStore do
  alias UrbitEx.Utils
  alias UrbitEx.{Resource}


  def create(name, title, description, "open", opts) do
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

  def create(name, title, description, "invite", opts) do
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

  def delete(resource) do
    %{
      remove: %{
        ship: resource.ship,
        name: resource.name
      }
    }
  end

  def cancel_join(resource) do
    %{hide: Resource.to_url(resource)}
  end

  def leave(resource) do
    %{
      leave: %{
        ship: resource.ship,
        name: resource.name
      }
    }
  end

  def change_policy(resource, type) do
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

  def ban(resource, type, targets) do
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

  def invite(resource, invitees, message) do
    %{
      invite: %{
        ships: invitees,
        description: message,
        resource: resource
      }
    }
  end

  def kick(group, ships) do
    %{
      removeMembers: %{
        resource: group,
        ships: ships
      }
    }
  end

  def add_tag(resource, tag, ships) do
    %{
      addTag: %{
        resource: resource,
        ships: ships,
        tag: tag
      }
    }
  end

  def remove_tag(resource, tag, ships) do
    %{
      removeTag: %{
        resource: resource,
        ships: ships,
        tag: tag
      }
    }
  end
end
