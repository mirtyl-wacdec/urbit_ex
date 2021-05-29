defmodule UrbitEx.Airlock do
  @moduledoc """
    Module with functions to interact with Eyre. All HTTP requests sent to Urbit are in this module.
  """

  # body must be a list

  def put(url, channel, cookie, body) do
    endpoint = url <> channel
    body = Jason.encode!(body)

    headers = %{
      "Content-type" => "application/json",
      "Cookie" => cookie
    }

    HTTPoison.put(endpoint, body, headers)
  end

  # used to login
  def post(endpoint, body) do
    HTTPoison.post(endpoint, body)
  end

  def post(endpoint, body, cookie) do
    headers = %{
      "Content-type" => "application/json",
      # "Content-type" => "text/plain;charset=UTF-8",
      "Cookie" => cookie
    }

    body = Jason.encode!(body)

    HTTPoison.post(endpoint, body, headers)
  end

  def get(url, cookie) do
    headers = %{
      "Content-type" => "application/json",
      "Cookie" => cookie
    }

    HTTPoison.get(url, headers)
  end

  def sse(url, channel, cookie, last_event) do
    endpoint = url <> channel

    headers = %{
      "Connection" => "keep-alive",
      "Accept" => "text/event-stream",
      "Cookie" => cookie,
      "Cache-Control" => "no-cache",
      "User-Agent" => "UrbitEx",
      "Last-Event-ID" => last_event
    }

    sse_options = [stream_to: self(), recv_timeout: :infinity]

    HTTPoison.get(endpoint, headers, sse_options)
  end
end
