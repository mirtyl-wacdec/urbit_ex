defmodule UrbitEx.Timebox do
  alias UrbitEx.{Utils, Notification}
  # on fetching notifications you receive a list (not a graph) of maps
  # each map contains a single "timebox" key, whose value is a map with three keys:
  defstruct archive: false,
            notifications: [],
            time: Utils.parse_index("170.141.184.505.078.721.182.092.750.343.955.808.256")

  def new(timebox) when is_map(timebox) do
    nots = timebox["notifications"] |> Enum.map(&Notification.new/1)

    %__MODULE__{
      archive: timebox["archive"],
      time: Utils.parse_index(timebox["time"]),
      notifications: nots
    }
  end
end
