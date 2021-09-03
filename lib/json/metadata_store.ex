defmodule UrbitEx.MetadataStore do
    alias UrbitEx.{Resource}

    def edit(group, resource, type, key, value) do
      %{
        edit: %{
          edit: %{key => value},
          group: Resource.to_url(group),
          resource: %{
            "app-name": type,
            resource: Resource.to_url(resource)
          }
        }
      }
    end
end
