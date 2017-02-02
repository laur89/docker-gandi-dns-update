# Seafile for Docker

[Seafile](http://www.seafile.com/) is a "next-generation open source cloud storage
with advanced features on file syncing, privacy protection and teamwork".

This Dockerfile does not really package Seafile for Docker, but provides an environment
for running it including startup scripts, including all dependencies for SQLite.

Provides with only SQLite-backed installation (no MySQL at this point).
Note this installation of seafile is intended to be ran behind a reverse proxy over https.
An example of nginx config that could be used is included.

## Setup

First the embedded `setup-seafile` script is executed when running the image for the
first time, that installs & sets up seafile under `/seafile`.
[Reading through the setup manual](https://github.com/haiwen/seafile/wiki/Download-and-setup-seafile-server)
before setting up Seafile is recommended.
If you're using this docker on unraid, this means running the `docker run` command
below from command line, not from template. When container exits, it should be removed.

Run the image in a container, exposing ports as needed and making `/seafile` volume permanent:

* `VER`: actual ver (eg `6.0.7`), or `latest`
* `SERVER_IP`: domain or IP of the box where seafile is set up; without the protocol

For example, you could use following command to install & setup

    docker run -it \
      -e VER=latest \
      -e SERVER_NAME=seafile-server \
      -e SERVER_IP=seafile.yourdomain.com \
      -e SEAHUB_ADMIN_USER=youradminuser \
      -e SEAHUB_ADMIN_PW=yourpassword \
      -v /path/on/host:/seafile \
      layr/docker-seafile -- setup-seafile

In case you want to use memcached instead of /tmp/seahub_cache/ add the following to
your seahub_settings.py:

    CACHES = {
      'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': 'memcached:11211',
      }
    }

Link your memcached instance to your seafile container by adding
`--link memcached_container:memcached` to your docker run statement.

## Running Seafile

Run the image again, this time you probably want to give it a name for using some
startup scripts.
**The image will autostart the `seafile` and `seahub` processes if the environment
variable `AUTOSTART=true` is set.** A reasonable docker command would be

    docker run -d \
      --name seafile \
      -p 10001:10001 \
      -p 12001:12001 \
      -p 8000:8000 \
      -p 8080:8080 \
      -p 8082:8082 \
      -v /path/on/host:/seafile \
      -e AUTOSTART=true \
      -e FASTCGI=true \
      layr/docker-seafile

For unraid users, this is the command that should to be converted into a Docker template.

## Updates and Maintenance

The Seafile binaries are stored in the permanent volume `/seafile`. To update the
base system, just stop and drop the container, update the image using
`docker pull layr/docker-seafile` and run it again. To update Seafile, follow the normal
upgrade process described in the [Seafile upgrade manual](https://github.com/haiwen/seafile/wiki/Upgrading-Seafile-Server).

