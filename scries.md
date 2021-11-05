Urbit agents expose scry endpoints to query state information without altering the agent's state.  These are all scry endpoints, but may be informally divided into the HTTP endpoints (registered with Eyre) and regular scry endpoints (exposed in `++on-peek`).

##  HTTP Endpoints

Each webapp is listed at the `app/appname` URL followed by the endpoints registered with Eyre.  These are directly registered with Eyre at the designated endpoint.

The standard agents activated by `%home` and `%base` expose the following endpoint paths:

- `%acme`
- `%azimuth-tracker`
- `%dbug`
  - `/~debug`
  - various per-agent `/dbug/scry` endpoints possible
- `%dojo`
- `%eth-watcher`
  - external endpoint
- `%hood`
- `%herm`
- `%language-server`
  - `/~language-server-protocol`
- `%lens`
- `%ping`
- `%spider`
  - `/spider`

The standard agents activated by `%landscape` expose the following endpoint paths:

- `%landscape`
  - `/~landscape/fonts`
  - `/~landscape/img`
  - `/~landscape/js`
  - `/~landscape`
  - various `%file-server` endpoints possible
- `%s3-store`
  - external endpoint

The standard agents activated by `%bitcoin` expose the following endpoint paths:

- `%bitcoin`
  - `/~bitcoin`

##  Scry Endpoints

The standard agents activated by `%home` and `%base` expose the following scry endpoint paths.  Scries with `%x` cares are available through the HTTP format `http{s}://{host}/~/scry/{app}{path}.{mark}`.  All scry cares are available through `.^` dotket.

- `%acme`
  - `[%x %domain-validation @t ~]`
- `%azimuth-tracker`
- `%dbug`
- `%dojo`
- `%eth-watcher`
  - `[%x %block ^]`
  - `[%x %dogs %configs ~]`
  - `[%x %dogs ~]`
- `%hood`
- `%herm`
- `%language-server`
- `%lens`
  - `[%x %export-all ~]`
- `%ping`
- `%spider`
  - `[%x %saxo @ ~]`
  - `[%x %starting @ ~]`
  - `[%x %tree ~]`

The standard agents activated by `%landscape` expose the following scry endpoint paths:

- `%metadata-store`
  - `[%x %app-name @ ~]`
  - `[%x %associations ~]`
  - `[%x %export ~]`
  - `[%x %group *]`
  - `[%x %metadata @ @ @ @ ~]`
  - `[%x %metadata-json @ @ @ @ ~]`
  - `[%x %resource @ *]`
  - `[%y %app-indices ~]`
  - `[%y %group-indices ~]`
  - `[%y %resource-indices ~]`
- `%glob`
  - `[%x %btc-wallet ~]`
- `%demo-store`
  - `[%x %log @ @ @ ~]`
- `%sane`
  - `[%x %bad-path ~]`
- `%invite-store`
  - `[%x %all ~]`
  - `[%x %export ~]`
  - `[%x %invitatory @ ~]`
  - `[%x %invite @ @ ~]`
- `%s3-store`
  - `[%x %configuration ~]`
  - `[%x %credentials ~]`
- `%graph-store`
  - `[%x %archive @ @ ~]`
  - `[%x %export ~]`
  - `[%x %graph @ @ *]`
  - `[%x %keys ~]`
  - `[%x %tag-queries *]`
  - `[%x %update-log @ @ *]`
- `%file-server`
  - `[%x %clay %base %hash ~]`
  - `[%x %our ~]`
  - `[%x %url *]`
- `%dm-hook`
  - `[%x %pendings ~]`
- `%launch`
  - `[%x %first-time ~]`
  - `[%x %keys ~]`
  - `[%x %runtime-lag ~]`
  - `[%x %tiles ~]`
- `%group-store`
  - `[%x %export ~]`
  - `[%x %groups %ship @ @ %join @ ~]`
  - `[%x %groups %ship @ @ ~]`
  - `[%y %groups ~]`
- `%contact-store`
  - `[%x %all ~]`
  - `[%x %allowed-groups ~]`
  - `[%x %allowed-ship @ ~]`
  - `[%x %is-allowed @ @ @ @ ~]`
  - `[%x %is-public ~]`
- `%push-hook`
  - `[%x %min-version ~]`
  - `[%x %sharing ~]`
  - `[%x %version ~]`
- `%pull-hook`
  - `[%x %dbug %state path]`
  - `[%x %tracking path]`
- `%shoe`
  - `[%x %dbug %state path]`

The standard agents activated by `%bitcoin` expose the following scry endpoint paths:

- `%btc-wallet`
  - `[%x %balance @ ~]`
  - `[%x %configured ~]`
  - `[%x %scanned ~]`
- `%btc-provider`
  - `[%x %is-client @t ~]`
  - `[%x %is-whitelisted @t ~]`

A scry may yield one of the following results:

- `200 OK` (with data) if the scry is successful
- `403 Forbidden` if the session cookie is invalid or missing
- `404 Missing` if no such scry endpoint can be found
- `500 Internal Server Error` if a mark conversion cannot be done


