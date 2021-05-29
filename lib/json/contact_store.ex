defmodule UrbitEx.ContactStore do
  def edit_field(ship, field, value) do
    %{
      edit: %{
        ship: ship,
        "edit-field": %{field => value},
        timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      }
    }
  end
end
