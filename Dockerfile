ARG ALPINE=3.18

# use target Alpine version as host
FROM alpine:${ALPINE} AS builder

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
RUN PGP_URI=https://raw.githubusercontent.com/bfren/clamav/main && \
    PGP_FILE=talos-public-pgp-key && \
    wget ${PGP_URI}/${PGP_FILE}-2023 && \
    wget ${PGP_URI}/${PGP_FILE}-2025 && \
    gpg --import ${PGP_FILE}-2023 ${PGP_FILE}-2025 || true

# download ClamAV source and verify signature
ARG CLAMAV=1.1.0
RUN CLAMAV_URI=https://www.clamav.net/downloads/production && \
    FILE=clamav-${CLAMAV}.tar.gz && \
    wget ${CLAMAV_URI}/${FILE} && \
    wget ${CLAMAV_URI}/${FILE}.sig && \
    gpg --verify -q ${FILE}.sig && \
    tar xzf ${FILE}

# build and configure ClamAV
WORKDIR /tmp/clamav-${CLAMAV}
RUN mkdir -p "./build" && cd "./build" && \
    cmake .. \
        -D CMAKE_BUILD_TYPE="Release" \
        -D CMAKE_INSTALL_PREFIX="/usr" \
        -D CMAKE_INSTALL_LIBDIR="/usr/lib" \
        -D APP_CONFIG_DIRECTORY="/etc/clamav" \
        -D DATABASE_DIRECTORY="/var/lib/clamav" \
        -D ENABLE_CLAMONACC=OFF \
        -D ENABLE_EXAMPLES=OFF \
        -D ENABLE_MILTER=ON \
        -D ENABLE_MAN_PAGES=OFF \
        -D ENABLE_STATIC_LIB=OFF \
        -D ENABLE_JSON_SHARED=ON \
    && \
    make DESTDIR="/clamav" -j$(($(nproc) - 1)) install && \
    rm -r "/clamav/usr/lib/pkgconfig/" && \
    ctest -V

# copy compiled files to final image
FROM scratch as final
COPY --from=builder /clamav /
