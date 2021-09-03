defmodule UrbitEx.Resource do
  @derive Jason.Encoder
  defstruct ship: "~mirtyl-wacdec",
            name: "apitest"

  def new(ship, name) do
    vship = validate_ship(ship)
    %UrbitEx.Resource{ship: vship, name: name}
  end

  def validate_ship(ship) do
    case UrbitEx.Utils.validate_patp(ship) do
      false -> raise ArgumentError, "invalid patp"
      match -> match
    end
  end

  def to_url(resource) do
    "/ship/#{resource.ship}/#{resource.name}"
  end

  def from_url(nil), do: nil

  def from_url(resource_url) do
    [_, ship, name] = String.split(resource_url, "/", trim: true)
    new(ship, name)
  end
end
