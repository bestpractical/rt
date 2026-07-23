# This Dockerfile is for testing only.

FROM bpssysadmin/rt-base-debian@sha256:8fead0595a786aad6e78b08a5f8b2bd2ad9558090a011646b7d64e16325f9d8f

ENV RT_TEST_PARALLEL 1
ENV RT_TEST_DEVEL 1
ENV RT_TEST_SMIME_REVOCATION 1
ENV RT_DBA_USER root
ENV RT_DBA_PASSWORD password
ENV RT_TEST_DB_HOST 172.17.0.2
ENV RT_TEST_RT_HOST 172.17.0.3

# Add the rt_test user (required by mod_fcgid tests)
RUN adduser --disabled-password --gecos "" rt-user

CMD tail -f /dev/null
