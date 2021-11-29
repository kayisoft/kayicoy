# Dockerfile --- build kayicoy docker image
#
# Copyright (C) 2021 Kayisoft, Inc.
#
# Author: Mohammad Matini <mohammad.matini@outlook.com>
# Maintainer: Mohammad Matini <mohammad.matini@outlook.com>
#
# Description: Builds a self-contained Debian-based Docker image of Kayicoy.
#
# This file is part of Kayicoy.
#
# Kayicoy is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Kayicoy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Kayicoy. If not, see <https://www.gnu.org/licenses/>.

FROM debian:11

# ----------------------------------------------------------------------------
#   Install application dependencies
# ----------------------------------------------------------------------------

RUN apt-get update &&\
        DEBIAN_FRONTEND=noninteractive apt-get -yq install \
        --no-install-recommends curl gnupg ca-certificates && \
        curl https://openresty.org/package/pubkey.gpg | apt-key add - && \
        echo "deb http://openresty.org/package/debian bullseye openresty" | \
        tee /etc/apt/sources.list.d/openresty.list && \
        apt-get update &&\
        DEBIAN_FRONTEND=noninteractive apt-get install -yq \
        --no-install-recommends openresty libsqlite3-dev libsodium-dev &&\
        DEBIAN_FRONTEND=noninteractive apt-get clean &&\
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ----------------------------------------------------------------------------
#   Setup Work Directory
# ----------------------------------------------------------------------------

RUN mkdir -p /opt/kayicoy/logs /opt/kayicoy/data
WORKDIR /opt/kayicoy/

# ----------------------------------------------------------------------------
#   Copy Source Code
# ----------------------------------------------------------------------------

COPY . .

# ----------------------------------------------------------------------------
#   Setup Image Entry-Point
# ----------------------------------------------------------------------------

ENTRYPOINT ["openresty", "-p", "/opt/kayicoy/", "-c", "/opt/kayicoy/config/nginx.conf", "-g", "daemon off;"]
