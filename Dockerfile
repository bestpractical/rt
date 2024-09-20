# This Dockerfile is for testing only.

FROM bpssysadmin/rt-base-debian:RT-6.0.0-bullseye-20240920

ENV RT_TEST_PARALLEL 1
ENV RT_TEST_DEVEL 1
ENV RT_DBA_USER root
ENV RT_DBA_PASSWORD password
ENV RT_TEST_DB_HOST=172.17.0.2
ENV RT_TEST_RT_HOST=172.17.0.3

# Add the rt_test user (required by mod_fcgid tests)
RUN adduser --disabled-password --gecos "" rt-user

CMD tail -f /dev/null
