FROM netsandbox/request-tracker-base

ENV RT_TEST_PARALLEL 1
ENV RT_DBA_USER root
ENV RT_DBA_PASSWORD password
ENV RT_TEST_DB_HOST=172.17.0.2
ENV RT_TEST_RT_HOST=172.17.0.3

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  git \
  autoconf \
  libnet-ldap-server-test-perl \
  libencode-hanextra-perl \
#  libhtml-gumbo-perl \
  libgumbo1 \
  build-essential \
  libhtml-formatexternal-perl \
  libdbd-mysql-perl \
  && rm -rf /var/lib/apt/lists/*

RUN cpanm \
  Encode::Detect::Detector \
  HTML::Gumbo
# && rm -rf /root/.cpanm

#RUN cd /usr/local/ \
#  && git clone https://github.com/bestpractical/rt.git \
#  && cd rt \
#  && git checkout "${RT_BRANCH}" \
#  && ./configure.ac \
#    --with-db-type=SQLite --with-my-user-group --enable-layout=inplace --enable-developer \
#    --enable-developer --enable-externalauth --disable-gpg --disable-smime \
#  && make testdeps
#  && make initdb

#RUN mkdir -p /usr/local/rt/var

#COPY t/data/configs/docker+apache2.4+fcgid.conf /etc/apache2/sites-available/rt.conf
#RUN a2dissite 000-default.conf && a2ensite rt.conf

#RUN chown -R www-data:www-data /usr/local/rt/var/

# COPY RT_SiteConfig.pm /opt/rt4/etc/RT_SiteConfig.pm

# VOLUME /opt/rt4

# COPY docker-entrypoint.sh /usr/local/bin/

# ENTRYPOINT ["docker-entrypoint.sh"]

# CMD ["apache2-foreground"]
