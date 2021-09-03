defmodule UrbitEx.S3Config do
  @derive Jason.Encoder

  defstruct login: nil,
            password: nil,
            endpoint: nil,
            buckets: [],
            current_bucket: nil
end
