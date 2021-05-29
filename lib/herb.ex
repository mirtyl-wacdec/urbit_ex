defmodule UrbitEx.Herb do
  def herb(loopbackport, command) do
    body = %{
      source: %{dojo: command},
      sink: %{stdout: nil}
    }

    headers = %{
      Accept: "*/*",
      "Accept-Encoding": "gzip, deflate",
      Connection: "keep-alive",
      "User-Agent": "python-requests/2.25.1"
    }

    {:ok, res} = HTTPoison.post("http://localhost:#{loopbackport}", Jason.encode!(body), headers)
    IO.inspect(res)
  end
end


