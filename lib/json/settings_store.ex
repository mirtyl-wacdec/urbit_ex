defmodule UrbitEx.SettingsStore do
  def put_entry(desk, bucket, entry, value) do
    %{
      "put-entry": %{
        desk: desk,
        "bucket-key": bucket,
        "entry-key": entry,
        value: value
      }
    }
  end

  def del_entry(desk, bucket, entry) do
    %{
      "del-entry": %{
        desk: desk,
        "bucket-key": bucket,
        "entry-key": entry
      }
    }
  end

  def put_bucket(desk, bucket), do: %{"put-bucket": %{desk: desk, "bucket-key": bucket, bucket: %{}}}
  def del_bucket(desk, bucket), do: %{"del-bucket": %{desk: desk, "bucket-key": bucket}}

  def s3(key, value), do: %{key => value}
end
