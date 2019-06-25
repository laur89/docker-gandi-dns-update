# Gandi DNS updater

Dockerised [gandi-dns-update](https://github.com/brianpcurran/gandi-automatic-dns)
shellscript to maintain A records in [Gandi](https://www.gandi.net) zonefile. The script updates a gandi
domain zone record with your current external ip.

## Running

Used environment variables for configuration:

- `API_KEY`: gandi api key
- `DOMAIN`: managed domain (eg `example.com`)
- `A_RECORDS`: space separated A records to update (eg `@ www blog`); optional if only `C_RECORDS` are wanted
- `C_RECORDS`: space separated CNAME records to update (eg `www blog target.com`); optional if only `A_RECORDS` are wanted
  note this takes semicolon-separated list of records in format `name1 name2 nameN target`, eg
  `ftp target1.example.com;blog web mail target2.example.com` would create CNAME record for `ftp` pointing to `target1.example.com`,
  and `blog, web, mail` subdomains pointing to `target2.example.com`
- `FORCE`: `true|false`; pass `true` if gandi api should be called even if your IP hasn't changed since last update; Optinal - defaults to `false`
- `CRON_PATTERN`: cron pattern to be used to execute the script. Optional - execution defaults to every 15 min
(eg `*/5 * * * *` to execute every 5 minutes)

Example docker command:

	docker run -d \
		--name gandi-dns-update \
		-e API_KEY=your_gandi_api_key \
		-e DOMAIN=example.com \
		-e A_RECORDS='@ www' \
        -e C_RECORDS='ftp example.com;blog web mail target2.example.com' \
		-e CRON_PATTERN='*/5 * * * *' \
		layr/gandi-dns-update
