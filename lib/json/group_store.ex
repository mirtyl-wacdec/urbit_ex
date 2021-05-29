defmodule UrbitEx.Groups do
  def fetch_preview(host, groupname) do
    app = "metadata-pull-hook"
    path = "/preview/ship/~#{host}/#{groupname}"
    UrbitEx.Actions.subscribe("", app, path)
  end
end
