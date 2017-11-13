FROM perl:5.24

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    gnupg1 \
    graphviz \
    libgd-dev \
    libmariadbclient-dev \
    postfix \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/rt4

COPY t/docker/perl t/docker/carton           bin/
COPY etc/cpanfile t/docker/cpanfile.snapshot ./

RUN /opt/rt4/bin/carton install --deployment --without pg,oracle,modperl1,fastcgi

RUN groupadd -r rt && useradd -r -g rt rt

COPY .                                      build/

RUN cd build && \
    PERL=/opt/rt4/bin/perl ./configure.ac --with-web-user=rt --with-web-group=rt \
                                          --with-web-handler=standalone \
                                          --with-db-type=SQLite && \
    make testdeps install

CMD ["/opt/rt4/bin/rt-server"]

EXPOSE 8888
