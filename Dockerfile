ARG ALPINE=3.18
ARG TALOS_KEY

# use target Alpine version as host
FROM alpine:${ALPINE} AS build

# install prerequisites - see https://docs.clamav.net/manual/Installing/Installing-from-source-Unix.html#alpine
RUN apk update && apk add \
    `# install tools` \
    g++ gcc gdb gpg make cmake py3-pytest python3 valgrind \
    `# install clamav dependencies` \
    bzip2-dev check-dev curl-dev json-c-dev libmilter-dev libxml2-dev \
    linux-headers ncurses-dev openssl-dev pcre2-dev zlib-dev \
    `# install rust toolchain` \
    cargo rust
    
# import Talos PGP Public Key
WORKDIR /tmp
RUN wget https://raw.githubusercontent.com/bfren/clamav/main/talos-public-pgp-key && \
    gpg --import /tmp/talos-public-pgp-key

# download clamav source
ARG CLAMAV=1.1.0
RUN URI=https://www.clamav.net/downloads/production && \
    FILE=clamav-${CLAMAV}.tar.gz && \
    wget ${URI}/${FILE} && \
    wget ${URI}/${FILE}.sig && \
    gpg --verify ${FILE}.sig && \
    tar xzf ${FILE}

# build clamav binary
WORKDIR /tmp/clamav-${CLAMAV}
RUN mkdir build && cd build && \
    cmake .. \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D APP_CONFIG_DIRECTORY=/etc/clamav \
    -D DATABASE_DIRECTORY=/var/lib/clamav \
    -D ENABLE_JSON_SHARED=OFF && \
    cmake --build . && \
    ctest && \
    cmake --build . --target install

# copy installation files to /install
RUN xargs -a install_manifest.txt cp -t /install
