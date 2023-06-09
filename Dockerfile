ARG ALPINE=3.18

# use target Alpine version as build host
FROM alpine:${ALPINE} AS builder

ARG CLAMAV=1.1.0
ARG KEY_URI=https://raw.githubusercontent.com/bfren/clamav/main \
ARG KEY_FILE=talos-public-key \
ARG SRC_URI=https://www.clamav.net/downloads/production \
ARG SRC_FILE=clamav-${CLAMAV}.tar.gz

# install prerequisites
RUN apk add --no-cache \
        bsd-compat-headers \
        bzip2-dev \
        cargo \
        check-dev \
        cmake \
        curl-dev \
        file \
        g++ \
        gpg \
        gpg-agent \
        json-c-dev \
        libmilter-dev \
        libtool \
        libxml2-dev \
        linux-headers \
        make \
        musl-fts-dev \
        ncurses-dev \
        ncurses-dev \
        openssl-dev \
        pcre2-dev \
        py3-pytest \
        python3 \
        rust \
        zlib-dev

# import Talos PGP Public Keys
WORKDIR /tmp
RUN wget ${KEY_URI}/${KEY_FILE}-2023 && \
    wget ${KEY_URI}/${KEY_FILE}-2025 && \
    gpg --import -q ./${KEY_FILE}-2023 && \
    gpg --import -q ./${KEY_FILE}-2025

# download ClamAV source and verify signature
RUN wget ${SRC_URI}/${SRC_FILE} && \
    wget ${SRC_URI}/${SRC_FILE}.sig && \
    gpg --verify ${SRC_FILE}.sig
RUN tar xzf ${SRC_FILE}

# build and configure ClamAV
WORKDIR /tmp/clamav-${CLAMAV}
RUN mkdir "/clamav" && \
    cmake -B /clamav \
        -D CMAKE_BUILD_TYPE="Release" \
        -D CMAKE_INSTALL_PREFIX="/usr" \
        -D CMAKE_INSTALL_LIBDIR="/usr/lib" \
        -D APP_CONFIG_DIRECTORY="/etc/clamav" \
        -D DATABASE_DIRECTORY="/var/lib/clamav" \
        -D ENABLE_CLAMONACC=OFF \
        -D ENABLE_DOXYGEN=OFF \
        -D ENABLE_EXAMPLES=OFF \
        -D ENABLE_MILTER=ON \
        -D ENABLE_MAN_PAGES=OFF \
        -D ENABLE_STATIC_LIB=OFF \
        -D ENABLE_SYSTEMD=OFF \
        -D ENABLE_JSON_SHARED=ON
RUN cmake --build /clamav
RUN ctest --test-dir /clamav --output-on-failure

# copy compiled files to final image
FROM scratch as final
COPY --from=builder /clamav /
