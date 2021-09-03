defmodule UrbitEx.ContactStore do
  alias UrbitEx.{Utils, Resource}

  def edit_field(ship, field, value) do
    %{
      edit: %{
        ship: ship,
        "edit-field": %{field => value},
        timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      }
    }
  end

  def retrieve(ship) do
    ship = Utils.add_tilde(ship)
    %{add: %{resource: Resource.new(ship, ""), ship: ship}}
  end

  def share(ship) do
    ship = Utils.add_tilde(ship)
    %{share: ship}
  end
end
