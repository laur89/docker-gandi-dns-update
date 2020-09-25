# Gandi DNS updater

Dockerised service updating your [Gandi](https://www.gandi.net) domain's `A` & `CNAME` records.

## Running

Used environment variables for configuration:

- `API_KEY`: gandi api key
- `DOMAIN`: managed domain (eg `example.com`)
- `A_RECORDS`: space separated A records to update (eg `@ www blog`); optional if only `C_RECORDS` are wanted
- `C_RECORDS`: space separated CNAME records to update (eg `www blog target.com`); optional if only `A_RECORDS` are wanted;
  note this takes semicolon-separated list of records in format `name1 name2 nameN target`, eg
  `ftp target1.example.com.;blog web mail target2.example.com.` would create CNAME record for `ftp` pointing to `target1.example.com`,
  and `blog, web, mail` subdomains pointing to `target2.example.com`
- `OVERWRITE`: `true|false`; pass `true` if configured records should replace _all_ the existing records at every execution.
  Optinal - defaults to `false`
- `ALWAYS_PUBLISH_CNAME`: `true|false`; pass `true` if CNAME records should be published with every execution, not only with the one
  ran at the container startup; forced to `true` if `OVERWRITE=true`; Optinal - defaults to `false`
- `PUBLISH_ONLY_ON_IP_CHANGE`: `true|false`; pass `false` if gandi api should be called with every execution, not only when
  our IP has changed from previously known IP; Optinal - defaults to `true`
- `TTL`: dns entry ttl; Optional - defaults to 10800
- `CRON_PATTERN`: cron pattern to be used to execute the script. Optional - execution defaults to every 15 min
(eg `*/5 * * * *` to execute every 5 minutes)

Example docker command:

	docker run -d \
		--name gandi-dns-update \
		-e API_KEY=your_gandi_api_key \
		-e DOMAIN=example.com \
		-e A_RECORDS='@ www' \
		-e C_RECORDS='ftp example.com.;blog web mail target2.example.com.' \
		-e CRON_PATTERN='*/5 * * * *' \
		layr/gandi-dns-update
