defmodule UrbitEx.Actions do
  @moduledoc """
    Module with functions to build json bodies to send to Airlock.
    One function per Eyre action: ack, subscribe, unsubscribe and poke.
    Scries are simple get requests, see every gall module for details.
  """

  def ack(event_id) do
    %{
      "event-id": event_id,
      action: "ack"
    }
  end

  def subscribe(ship, app, path) do
    %{
      ship: ship,
      app: app,
      path: path,
      action: "subscribe"
    }
  end

  def unsubscribe(subscription) do
    %{
      subscription: subscription,
      action: "unsubscribe"
    }
  end

  def poke(ship, app, mark, json) do
    %{
      ship: ship,
      app: app,
      mark: mark,
      json: json,
      action: "poke"
    }
  end
end
