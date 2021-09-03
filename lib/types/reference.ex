defmodule UrbitEx.Reference do
  alias UrbitEx.Resource
  @derive Jason.Encoder


  defstruct channel: %Resource{},
            group: %Resource{},
            index: "/170141184504961348183296013984673562624"

  def new(reference) do
    %__MODULE__{
      group: Resource.from_url(reference["group"]),
      channel: Resource.from_url(reference["graph"]),
      index: reference["index"]
    }
  end
end
