# This Dockerfile is for testing only.

FROM bpssysadmin/rt-base-debian-stretch

ENV RT_TEST_PARALLEL 1
ENV RT_TEST_DEVEL 1
ENV RT_TEST_DB_HOST=172.17.0.2
ENV RT_TEST_RT_HOST=172.17.0.3

# These APACHE ENVs are set as needed .travis.yml for CI
# They are here for convenience when testing manually on Apache
#ENV RT_TEST_WEB_HANDLER=apache+fcgid
#ENV HTTPD_ROOT=/etc/apache2
#ENV RT_TEST_APACHE=/usr/sbin/apache2
#ENV RT_TEST_APACHE_MODULES=/usr/lib/apache2/modules
#ENV RT_DBA_USER=root
#ENV RT_DBA_PASSWORD=password

# Add the rt_test user (required by mod_fcgid tests)
RUN adduser --disabled-password --gecos "" rt-user

CMD tail -f /dev/null
