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
end
