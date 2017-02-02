# Gandi DNS updater

Dockerised [gandi-dns-update](https://github.com/brianpcurran/gandi-automatic-dns)
shellscript to maintain A or AAAA records in Gandi zonefile. The script updates a gandi
domain zone record with your current external ip.

## Setup

Used environment variables:

`API_KEY`: gandi api key
`ZONE`: zone name to be managed (eg *example.com*)
`RECORD`: comma separated records to update (eg *@,www*)
`CRON_PATTERN`: cron pattern to be used to execute the script. Optional - default to TODO
