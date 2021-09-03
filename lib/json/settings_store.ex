defmodule UrbitEx.SettingsStore do
  def put_entry(bucket, entry, value) do
    %{
      "put-entry": %{
        "bucket-key": bucket,
        "entry-key": entry,
        value: value
      }
    }
  end

  def del_entry(bucket, entry) do
    %{
      "del-entry": %{
        "bucket-key": bucket,
        "entry-key": entry
      }
    }
  end

  def put_bucket(bucket), do: %{"put-bucket": %{"bucket-key": bucket, bucket: %{}}}
  def del_bucket(bucket), do: %{"del-bucket": %{"bucket-key": bucket}}

  def s3(key, value), do: %{key => value}
end
