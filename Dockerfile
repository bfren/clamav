ARG ALPINE=3.18

# use target Alpine version as host
FROM alpine:${ALPINE} AS builder

# install prerequisites - see https://github.com/Cisco-Talos/clamav-docker
RUN apk add --no-cache \
        bsd-compat-headers \
        cmake \
        file \
        g++ \
        libtool \
        linux-headers \
        make \
        musl-fts-dev \
        # Clamav dependencies provided by alpine
        bzip2-dev \
        check-dev \
        curl-dev \
        json-c-dev \
        libmilter-dev \
        libxml2-dev \
        ncurses-dev \
        ncurses-dev \
        openssl-dev \
        pcre2-dev \
        zlib-dev \
        # For the tests
        python3 \
        py3-pytest \
        # For Rust/Cargo
        cargo \
        rust

# download clamav source
ARG CLAMAV=1.1.0
WORKDIR /tmp
RUN URI=https://www.clamav.net/downloads/production && \
    FILE=clamav-${CLAMAV}.tar.gz && \
    wget ${URI}/${FILE} && \
    wget ${URI}/${FILE}.sig && \
    tar xzf ${FILE}

# build and configure clamav - see https://github.com/Cisco-Talos/clamav-docker
WORKDIR /tmp/clamav-${CLAMAV}
RUN mkdir -p "./build" && cd "./build" && \
    cmake .. \
        -D CMAKE_BUILD_TYPE="Release"                                                       \
        -D CMAKE_INSTALL_PREFIX="/usr"                                                      \
        -D CMAKE_INSTALL_LIBDIR="/usr/lib"                                                  \
        -D APP_CONFIG_DIRECTORY="/etc/clamav"                                               \
        -D DATABASE_DIRECTORY="/var/lib/clamav"                                             \
        -D ENABLE_CLAMONACC=OFF                                                             \
        -D ENABLE_EXAMPLES=OFF                                                              \
        -D ENABLE_MILTER=ON                                                                 \
        -D ENABLE_MAN_PAGES=OFF                                                             \
        -D ENABLE_STATIC_LIB=OFF                                                            \
        -D ENABLE_JSON_SHARED=ON                                                            \
    && \
    make DESTDIR="/clamav" -j$(($(nproc) - 1)) install && \
    rm -r \
       "/clamav/usr/lib/pkgconfig/" \
    && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /tmp/clamd.pid|" \
        -e "s|.*\(LocalSocket\) .*|\1 /tmp/clamd.sock|" \
        -e "s|.*\(TCPSocket\) .*|\1 3310|" \
        -e "s|.*\(TCPAddr\) .*|#\1 0.0.0.0|" \
        -e "s|.*\(User\) .*|\1 clamav|" \
        -e "s|^\#\(LogFile\) .*|\1 /var/log/clamav/clamd.log|" \
        -e "s|^\#\(LogTime\).*|\1 yes|" \
        "/clamav/etc/clamav/clamd.conf.sample" > "/clamav/etc/clamav/clamd.conf" && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /tmp/freshclam.pid|" \
        -e "s|.*\(DatabaseOwner\) .*|\1 clamav|" \
        -e "s|^\#\(UpdateLogFile\) .*|\1 /var/log/clamav/freshclam.log|" \
        -e "s|^\#\(NotifyClamd\).*|\1 /etc/clamav/clamd.conf|" \
        -e "s|^\#\(ScriptedUpdates\).*|\1 yes|" \
        "/clamav/etc/clamav/freshclam.conf.sample" > "/clamav/etc/clamav/freshclam.conf" && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /tmp/clamav-milter.pid|" \
        -e "s|.*\(MilterSocket\) .*|\1 inet:7357|" \
        -e "s|.*\(User\) .*|\1 clamav|" \
        -e "s|^\#\(LogFile\) .*|\1 /var/log/clamav/milter.log|" \
        -e "s|^\#\(LogTime\).*|\1 yes|" \
        -e "s|.*\(\ClamdSocket\) .*|\1 unix:/tmp/clamd.sock|" \
        "/clamav/etc/clamav/clamav-milter.conf.sample" > "/clamav/etc/clamav/clamav-milter.conf" || \
    exit 1 \
    && \
    ctest -V

# copy compiled files to final image
FROM scratch as final
COPY --from=builder /clamav /
