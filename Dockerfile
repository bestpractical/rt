FROM netsandbox/request-tracker-base

ENV RT_BRANCH 4.4/docker-tests

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  git \
  autoconf \
  libnet-ldap-server-test-perl \
  libencode-hanextra-perl \
  && rm -rf /var/lib/apt/lists/*

RUN cd /usr/local/ \
  && git clone https://github.com/bestpractical/rt.git \
  && cd rt \
  && git checkout "${RT_BRANCH}" \
  && ./configure.ac \
    --with-db-type=SQLite --with-my-user-group --enable-layout=inplace --enable-developer \
    --enable-developer --enable-externalauth --disable-gpg --disable-smime \
  && make testdeps
#  && make initdb

RUN mkdir -p /usr/local/rt/var

COPY t/data/configs/docker+apache2.4+fcgid.conf /etc/apache2/sites-available/rt.conf
RUN a2dissite 000-default.conf && a2ensite rt.conf

RUN chown -R www-data:www-data /usr/local/rt/var/

# COPY RT_SiteConfig.pm /opt/rt4/etc/RT_SiteConfig.pm

# VOLUME /opt/rt4

# COPY docker-entrypoint.sh /usr/local/bin/

# ENTRYPOINT ["docker-entrypoint.sh"]

# CMD ["apache2-foreground"]

#RUN cd /usr/local/rt \
#  && prove -l t/00-compile.t \
#  && prove -l t/00-mason-syntax.t \
#  && prove -l t/99-policy.t \
#  && prove -l t/web/ticket-display.t
