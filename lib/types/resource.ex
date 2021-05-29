defmodule UrbitEx.Resource do
  @derive Jason.Encoder
  defstruct ship: "~mirtyl-wacdec",
            name: "apitest"

  def new(ship, name) do
    vship = validate_ship(ship)
    %UrbitEx.Resource{ship: vship, name: name}
  end

  def validate_ship(ship) do
    match = UrbitEx.Utils.check_patp(ship)

    case match do
      true -> UrbitEx.Utils.add_tilde(ship)
      false -> raise UrbitEx.Resource.Invalid, message: "invalid patp"
    end
  end
end
