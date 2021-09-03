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

    HTTPoison.put(endpoint, body, headers, follow_redirect: true)
  end

  # used to login
  def post(endpoint, body) do
    HTTPoison.post(endpoint, body, [], follow_redirect: true)
  end

  def post(endpoint, body, cookie) do
    headers = %{
      "Content-type" => "application/json",
      # "Content-type" => "text/plain;charset=UTF-8",
      "Cookie" => cookie
    }
    body = Jason.encode!(body)
    HTTPoison.post(endpoint, body, headers, follow_redirect: true)
  end

  def get(url, cookie) do
    headers = %{
      "Content-type" => "application/json",
      "Cookie" => cookie
    }

    HTTPoison.get(url, headers, follow_redirect: true)
  end

  def sse(url, channel, cookie, opts \\ [reconnect: false]) do
    endpoint = url <> channel.path
    headers = %{
      "Connection" => "keep-alive",
      "Accept" => "text/event-stream",
      "Cookie" => cookie,
      "Cache-Control" => "no-cache",
      "User-Agent" => "UrbitEx"
    }
    headers = if opts[:reconnect], do: Map.put(headers, "Last-Event-Id", channel.last_sse), else: headers
    sse_options = [stream_to: self(), recv_timeout: :infinity, follow_redirect: true]
    HTTPoison.get(endpoint, headers, sse_options)
  end


end
