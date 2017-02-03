# Gandi DNS updater

Dockerised [gandi-dns-update](https://github.com/brianpcurran/gandi-automatic-dns)
shellscript to maintain A records in [Gandi](https://www.gandi.net) zonefile. The script updates a gandi
domain zone record with your current external ip.

## Running

Used environment variables for configuration:

- `API_KEY`: gandi api key
- `ZONE`: zone name to be managed (eg `example.com`)
- `RECORD`: space separated records to update (eg `@ www blog`)
- `CRON_PATTERN`: cron pattern to be used to execute the script. Optional - execution defaults to every 15 min
(eg `*/5 * * * *` to execute every 5 minutes)

Example docker command:

	docker run -d \
		--name gandi-dns-update \
		-e API_KEY=your_gandi_api_key \
		-e ZONE=example.com \
		-e RECORD='@ www' \
		-e CRON_PATTERN='*/5 * * * *' \
		layr/gandi-dns-update

