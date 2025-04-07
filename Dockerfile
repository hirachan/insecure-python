# Build Python environment which can use SSL3.0, TLS1.0, TLS1.1
FROM debian:bookworm AS builder

ENV PYTHON_VER 3.13.2
ENV OPENSSL_VER 3.4.1

RUN apt update && \
    apt install -y wget make gcc g++ perl libffi-dev xz-utils libz-dev ca-certificates libreadline-dev tzdata

# Build OpenSSL with SSL3.0
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz && \
    tar xzf openssl-${OPENSSL_VER}.tar.gz && \
    rm openssl-${OPENSSL_VER}.tar.gz

RUN cd openssl-${OPENSSL_VER} && \
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/ssl enable-ssl3 enable-ssl3-method enable-weak-ssl-ciphers && \
    make && \
    make install && \
    cd /usr/local/openssl && \
    ln -s lib64 lib && \
    mv /usr/local/ssl /usr/local/ssl.org && \
    cp -a /etc/ssl /usr/local/

RUN cd /usr/local/ssl && \
    echo '[system_default_sect]' >> /usr/local/ssl/openssl.cnf && \
    echo 'MinProtocol = None' >> /usr/local/ssl/openssl.cnf && \
    echo 'CipherString = DEFAULT@SECLEVEL=0' >> /usr/local/ssl/openssl.cnf

# Build Python
RUN wget https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tgz && \
    tar xvzf Python-${PYTHON_VER}.tgz && \
    rm Python-${PYTHON_VER}.tgz

RUN cd Python-${PYTHON_VER} && \
    ./configure --with-openssl=/usr/local/openssl --with-openssl-rpath=auto --enable-optimizations --with-ssl-default-suites=openssl && \
    make install && \
    cd .. && \
    rm -rf Python-${PYTHON_VER}

RUN cd /usr/local && \
    tar czf usr_local.tar.gz bin lib include ssl openssl

FROM debian:bookworm-slim AS runner

RUN apt update && \
    apt install -y libffi-dev xz-utils libz-dev ca-certificates libreadline-dev tzdata

COPY --from=builder /usr/local/usr_local.tar.gz /usr/local/
RUN cd /usr/local && \
    tar xzf usr_local.tar.gz && \
    rm usr_local.tar.gz


ENTRYPOINT ["/usr/local/bin/python3"]
