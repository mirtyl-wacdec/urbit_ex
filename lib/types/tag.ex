defmodule UrbitEx.Tag do
  @derive Jason.Encoder
  alias UrbitEx.Resource

  defstruct app: "graph",
            tag: "writers",
            resource: "/ship/~sampel-planet/resource-4503"

  def new(resource) do
    %__MODULE__{app: "graph", tag: "writers", resource: Resource.to_url(resource)}
  end
end
