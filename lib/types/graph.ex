defmodule UrbitEx.Graph do
  alias UrbitEx.{Node}
  @derive Jason.Encoder


  # def new(graph) do
  #   # :gb_trees . Some day.
  # end

  def to_list(nil), do: []

  def to_list(graph) do
    Map.keys(graph)
    |> Enum.map(&(graph[&1] |> Map.put(:index, &1)))
    |> Enum.map(&Node.new(&1, &1.index))
  end

  def weed(nil), do: nil

  def weed(graph) when is_map(graph) do
   Map.new(graph, &do_weed/1) |> Map.delete(:nil)
  end

  def do_weed({k, %{"children" => children, "post" => post}}) do
    if !is_map(post) do
      {:nil, nil}
    else
      {k, %{"children" => weed(children), "post" => post}}
    end
  end

end
