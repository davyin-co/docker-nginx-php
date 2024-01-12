#!/bin/bash
### https://blog.dockbit.com/templating-your-dockerfile-like-a-boss-2a84a67d28e9
render() {
sedStr="
  s!%%PHP_VERSION%%!$version!g;
  s!%%ALPINE_PHP_VERSION%%!$alpine_php_version!g;
"

sed -r "$sedStr" $1
}

versions=(7.1 7.2 7.3 7.4 8.0 8.1 8.2 8.3)
for version in ${versions[*]}; do
  if [ ! -d ${version}/alpine ]; then
    mkdir -p ${version}/alpine
  fi
  if [[ "${version}" = "7.1" ||  "${version}" = "7.2" ]]; then
    alpine_php_version=7
  fi
  if [[ "${version}" = "8.0" ]]; then
    alpine_php_version=8
  fi
  if [[ "${version}" = "8.1"  ]]; then
    alpine_php_version=81
  fi
  if [[ "${version}" = "8.2"  ]]; then
    alpine_php_version=82
  fi
  if [[ "${version}" = "8.3"  ]]; then
    alpine_php_version=83
  fi
  render Dockerfile-alpine.template > $version/alpine/Dockerfile
  # https://github.com/flyve-mdm/docker-environment/issues/68
  if [ "${version}" = "7.1" ]; then
    sed -i "s/pecl install xdebug/pecl install xdebug-2.9.0/g" ${version}/alpine/Dockerfile
  fi
  ## php:7.1-fpm-alpile stick on alpine 3.10.
  if [[ "${version}" = "7.1" ||  "${version}" = "7.2" ]]; then
    sed -i "s/libpq-dev/postgresql-libs postgresql-dev /g" ${version}/alpine/Dockerfile
  fi
  # https://www.php.net/manual/en/image.installation.php
  # php 7.4 gd config differenct as before.
  if [[ "${version}" = "7.4" || "${version}" = "8.0" || "${version}" = "8.1" || "${version}" = "8.2" || "${version}" = "8.3" ]]; then
    sed -i "s/with-gd/enable-gd/g" ${version}/alpine/Dockerfile
    sed -i "s/--with-png-dir=\/usr\/include\///g" ${version}/alpine/Dockerfile
    sed -i "s/-dir=/=/g" ${version}/alpine/Dockerfile
  fi
done
# for version in ${versions[*]}; do
#   if [ ! -d ${version}/debian ]; then
#     mkdir -p ${version}/debian
#   fi
#   if [[ "${version}" = "7.1" ||  "${version}" = "7.2" ]]; then
#     alpine_php_version=7
#   fi
#   if [[ "${version}" = "8.0" ]]; then
#     alpine_php_version=8
#   fi
#   if [[ "${version}" = "8.1"  ]]; then
#     alpine_php_version=81
#   fi
#   if [[ "${version}" = "8.2"  ]]; then
#     alpine_php_version=82
#   fi
#   if [[ "${version}" = "8.3"  ]]; then
#     alpine_php_version=83
#   fi
#   render Dockerfile-debian.template > $version/debian/Dockerfile
#   # https://github.com/flyve-mdm/docker-environment/issues/68
#   if [ "${version}" = "7.1" ]; then
#     sed -i "s/pecl install xdebug/pecl install xdebug-2.9.0/g" ${version}/debian/Dockerfile
#   fi
#   ## php:7.1-fpm-alpile stick on alpine 3.10.
#   if [[ "${version}" = "7.1" ||  "${version}" = "7.2" ]]; then
#     sed -i "s/libpq-dev/postgresql-libs postgresql-dev /g" ${version}/debian/Dockerfile
#   fi
#   # https://www.php.net/manual/en/image.installation.php
#   # php 7.4 gd config differenct as before.
#   if [[ "${version}" = "7.4" || "${version}" = "8.0" || "${version}" = "8.1" || "${version}" = "8.2" || "${version}" = "8.3" ]]; then
#     sed -i "s/with-gd/enable-gd/g" ${version}/debian/Dockerfile
#     sed -i "s/--with-png-dir=\/usr\/include\///g" ${version}/debian/Dockerfile
#     sed -i "s/-dir=/=/g" ${version}/debian/Dockerfile
#   fi
# done
