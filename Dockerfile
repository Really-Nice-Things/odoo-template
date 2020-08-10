FROM debian:jessie
LABEL maintainer="Adapta Blue SL <admin@reallynicethings.es>"

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
  apt-get update \
  && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  dirmngr \
  node-less \
  python-gevent \
  python-ldap \
  python-pip \
  python-qrcode \
  python-renderpm \
  python-support \
  python-vobject \
  python-watchdog \
  && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.jessie_amd64.deb \
  && echo '4d104ff338dc2d2083457b3b1e9baab8ddf14202 wkhtmltox.deb' | sha1sum -c - \
  && dpkg --force-depends -i wkhtmltox.deb \
  && apt-get -y install -f --no-install-recommends \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false npm \
  && rm -rf /var/lib/apt/lists/* wkhtmltox.deb \
  && pip install psycogreen==1.0

# install latest postgresql-client
RUN set -x; \
  echo 'deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main' > etc/apt/sources.list.d/pgdg.list \
  && export GNUPGHOME="$(mktemp -d)" \
  && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
  && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
  && gpg --armor --export "${repokey}" | apt-key add - \
  && rm -rf "$GNUPGHOME" \
  && apt-get update  \
  && apt-get install -y postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# CUSTOMIZATIONS
RUN set -x; \
  mkdir /deb_depends \
  && curl -o /deb_depends/libxslt1.1.deb -SL http://ftp.de.debian.org/debian/pool/main/libx/libxslt/libxslt1.1_1.1.28-2+deb8u3_amd64.deb \
  && curl -o /deb_depends/libxml2.deb -SL http://ftp.de.debian.org/debian/pool/main/g/glibc/multiarch-support_2.19-18+deb8u10_amd64.deb \
  && curl -o /deb_depends/python-crypto.deb -SL http://ftp.de.debian.org/debian/pool/main/p/python-crypto/python-crypto_2.6.1-5+deb8u1_amd64.deb \
  && curl -o /deb_depends/libssl-dev.deb -SL http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl-dev_1.0.1t-1+deb8u12_amd64.deb \
  && curl -o /deb_depends/libffi-dev.deb -SL http://ftp.de.debian.org/debian/pool/main/libf/libffi/libffi-dev_3.1-2+deb8u1_amd64.deb \
  && curl -o /deb_depends/python-lxml.deb -SL http://ftp.de.debian.org/debian/pool/main/l/lxml/python-lxml_3.4.0-1_amd64.deb\
  && curl -o /deb_depends/libavahi-client3.deb -SL http://ftp.de.debian.org/debian/pool/main/a/avahi/libavahi-client3_0.6.31-5_amd64.deb \
  && curl -o /deb_depends/libavahi-common3.deb -SL http://ftp.de.debian.org/debian/pool/main/a/avahi/libavahi-common3_0.6.31-5_amd64.deb \
  && curl -o /deb_depends/libdbus-1-3.deb -SL http://ftp.de.debian.org/debian/pool/main/d/dbus/libdbus-1-3_1.8.22-0+deb8u1_amd64.deb \
  && curl -o /deb_depends/libavahi-common-data.deb -SL http://ftp.de.debian.org/debian/pool/main/a/avahi/libavahi-common-data_0.6.31-5_amd64.deb \
  && curl -o /deb_depends/libcups2.deb -SL http://ftp.de.debian.org/debian/pool/main/g/glibc/multiarch-support_2.19-18+deb8u10_amd64.deb \
  && curl -o /deb_depends/python-cups.deb -SL http://ftp.de.debian.org/debian/pool/main/p/python-cups/python-cups_1.9.73-2+b1_amd64.deb \
  && dpkg --force-depends -i /deb_depends/*.deb \
  && apt-get update \
  && apt-get -y install -f --no-install-recommends \
  && rm -rf \
  /var/lib/apt/lists/* python-crypto.deb \
  /var/lib/apt/lists/* libssl-dev.deb \
  /var/lib/apt/lists/* libffi-dev.deb \
  /var/lib/apt/lists/* python-lxml.deb \
  && rm -dfr /deb_depends

# Needed requirements
RUN set -x; \
  apt-get update \
  && apt-get -y install --no-install-recommends build-essential python-dev \
  && pip install setuptools==20.7.0

# Install python requirements.txt
ADD ./requirements.txt /requirements.txt
RUN pip install -r /requirements.txt 

# Install Python zeep for SII
RUN set -x; \
  pip install zeep

# Install Odoo
ENV ODOO_VERSION 8.0
ARG ODOO_RELEASE=20171001
ARG ODOO_SHA=c41c6eaf93015234b4b62125436856a482720c3d
RUN set -x; \
  curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
  && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
  && dpkg --force-depends -i odoo.deb \
  && apt-get update \
  && apt-get -y install -f --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* odoo.deb

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./config/openerp-server.conf /etc/odoo/
RUN chown odoo /etc/odoo/openerp-server.conf

# Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN mkdir -p /mnt/extra-addons \
  && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8072

# Set the default config file
ENV OPENERP_SERVER /etc/odoo/openerp-server.conf

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["openerp-server"]

