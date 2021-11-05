defmodule UrbitEx.API.Contacts do
  alias UrbitEx.{API, Airlock, Actions, ContactStore}
  # https://github.com/urbit/urbit/blob/master/pkg/interface/src/logic/api/contacts.ts
  def allowed(session) do
    entity = ""
    name = ""
    ship = ""
    is_personal = false
    endpoint = "/~/scry/contact-store/#{entity}/#{name}/#{ship}/#{is_personal}.json"
    {:ok, _res} = Airlock.get(session.url <> endpoint, session.cookie)
  end


  def retrieve(session, channel, ship) do
    json = ContactStore.retrieve(ship)
    body = Actions.poke(session.ship, "contact-pull-hook", "pull-hook-action", json)
    API.wrap_put(session, channel, [body])
  end

  def all(session, ship) do
    endpoint = "/~/scry/contact-store/all.json"
    case Airlock.get(session.url <> endpoint, session.cookie) do
      {:ok, res} ->
        case Jason.decode(res.body) do
          {:ok, b} -> {:ok, b["contact-update"]["add"]}
          {:error, reason} -> {:error, reason}
        end
      {:error, error} ->
        {:error, error}
    end
  end
  def get(session, ship) do
    endpoint = "/~/scry/contact-store/contact/#{ship}.json"
    case Airlock.get(session.url <> endpoint, session.cookie) do
      {:ok, res} ->
        case Jason.decode(res.body) do
          {:ok, b} -> {:ok, b["contact-update"]["add"]}
          {:error, reason} -> {:error, reason}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  def public?(session) do
    endpoint = "/~/scry/contact-store/is-public.json"
    case Airlock.get(session.url <> endpoint, session.cookie) do
      {:ok, res} ->
        case Jason.decode(res.body) do
          {:ok, b} -> {:ok, b["contact-update"]["add"]}
          {:error, reason} -> {:error, reason}
        end
      {:error, error} ->
        {:error, error}
    end
  end
  def allowed_groups(session) do
    endpoint = "/~/scry/contact-store/allowed-groups.json"
    case Airlock.get(session.url <> endpoint, session.cookie) do
      {:ok, res} ->
        case Jason.decode(res.body) do
          {:ok, b} -> {:ok, b["contact-update"]["add"]}
          {:error, reason} -> {:error, reason}
        end
      {:error, error} ->
        {:error, error}
    end
  end
end
