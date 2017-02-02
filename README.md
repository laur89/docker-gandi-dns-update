# Gandi DNS updater

Dockerised [gandi-dns-update](https://github.com/brianpcurran/gandi-automatic-dns)
shellscript to maintain A records in Gandi zonefile. The script updates a gandi
domain zone record with your current external ip.

## Setup

Used environment variables:

- `API_KEY`: gandi api key
- `ZONE`: zone name to be managed (eg *example.com*)
- `RECORD`: space separated records to update (eg *@ www blog*)
- `CRON_PATTERN`: cron pattern to be used to execute the script. Optional - defaults to every 15 min
(eg `*/5 * * * *` to execute every 5 minutes)
