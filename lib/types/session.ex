defmodule UrbitEx.Session do
  defstruct ship: "",
            url: "",
            code: "",
            channel: "",
            last_action: 0,
            last_sse: 0,
            last_ack: 0,
            subscriptions: [],
            recent_events: [],
            truncated_event: "",
            consumers: []
end
