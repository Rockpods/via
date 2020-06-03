FROM alpine:3.12.0
MAINTAINER Hypothes.is Project and Ilya Kreymer

# Install runtime deps.
RUN apk add --update \
    git \
    collectd \
    collectd-disk \
    curl \
    libffi \
    python2 \
    openssl \
    supervisor \
    squid \
  && rm -rf /var/cache/apk/*

# Install pip via get-pip.py as it is no longer packaged for Python 2 by Alpine.
# pip is a runtime as well as build dependency because it includes `pkg_resources`.
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python get-pip.py

# Create the via user, group, home directory and package directory.
RUN addgroup -S via && adduser -S -G via -h /var/lib/via via
WORKDIR /var/lib/via

ADD requirements.txt .

# Install build deps, build, and then clean up.
RUN apk add --update --virtual build-deps \
    build-base \
    git \
    libffi-dev \
    linux-headers \
    openssl-dev \
    python2-dev \
  && pip install --no-cache-dir -U pip \
  && pip install --no-cache-dir -r requirements.txt \
  && apk del build-deps \
  && rm -rf /var/cache/apk/*

# Copy collectd config
COPY conf/collectd.conf /etc/collectd/collectd.conf
RUN mkdir /etc/collectd/collectd.conf.d \
 && chown via:via /etc/collectd/collectd.conf.d

# Copy squid config
COPY conf/squid.conf /etc/squid/squid.conf
RUN mkdir /var/spool/squid \
 && chown via:via /var/run/squid /var/spool/squid /var/log/squid

# Use local squid by default
ENV HTTP_PROXY http://localhost:3128
ENV HTTPS_PROXY http://localhost:3128

ENV BLOCKLIST_PATH /tmp/blocklist.txt
COPY --chown=via via/default-blocklist.txt /tmp/blocklist.txt

# Install app.
COPY . .

EXPOSE 9080

CMD ["supervisord", "-c" , "conf/supervisord.conf"]
