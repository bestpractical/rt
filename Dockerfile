# This Dockerfile is for testing only.

FROM bpssysadmin/rt-base-debian-stretch

ENV RT_TEST_PARALLEL 1
ENV RT_TEST_DEVEL 1
ENV RT_TEST_DB_HOST=172.17.0.2
ENV RT_TEST_RT_HOST=172.17.0.3

# Skip gpg tests until we update to gpg 2.2
ENV SKIP_GPG_TESTS=1

# Add the rt_test user.  Apache/mod_fcgid refuses to run as root... so we
# create a non-root user and run the mod_fcgid tests as that user.
RUN adduser rt-test < /dev/null

CMD tail -f /dev/null
