defmodule UrbitEx.API.Channels do
  alias UrbitEx.{API, Actions, Tag, GroupStore}

  def restrict_writers(session, channel, group, resource, writers) when is_list(writers) do
    tag = Tag.new(resource)
    json = GroupStore.add_tag(group, tag, writers)
    body = Actions.poke(session.ship, "group-push-hook", "group-update-0", json)
    API.wrap_put(session, channel, [body])
  end
end
