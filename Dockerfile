ARG ALPINE=3.18
ARG CLAMAV=1.1.0

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
RUN CLAMAV_URI=https://www.clamav.net/downloads/production && \
    FILE=clamav-${CLAMAV}.tar.gz && \
    wget ${CLAMAV_URI}/${FILE} && \
    wget ${CLAMAV_URI}/${FILE}.sig && \
    gpg --verify -q ${FILE}.sig && \
    tar xzf ${FILE}

# build and configure ClamAV
WORKDIR /tmp/clamav-${CLAMAV}
RUN mkdir "/clamav" && \
    cmake -B /clamav -G Ninja \
        -D CMAKE_BUILD_TYPE="Release" \
        -D CMAKE_INSTALL_PREFIX=/usr \
	-D CMAKE_INSTALL_LIBDIR=/usr/lib \
	-D CMAKE_SKIP_INSTALL_RPATH=ON \
	-D APP_CONFIG_DIRECTORY=/etc/clamav \
	-D DATABASE_DIRECTORY=/var/lib/clamav \
	-D ENABLE_DOXYGEN=OFF \
	-D ENABLE_SYSTEMD=OFF \
	-D ENABLE_TESTS=ON \
	-D ENABLE_CLAMONACC=ON \
	-D ENABLE_MILTER=ON \
	-D ENABLE_EXTERNAL_MSPACK=ON \
	-D ENABLE_EXAMPLES=ON \
	-D ENABLE_EXAMPLES_DEFAULT=ON \
	-D HAVE_SYSTEM_LFS_FTS=ON \
	-D ENABLE_JSON_SHARED=ON \
    && \
    cmake --build /clamav && \
    ctest --test-dir /clamav --output-on-failure

# copy compiled files to final image
FROM scratch as final
COPY --from=builder /clamav /
