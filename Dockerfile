# syntax=docker/dockerfile:1

# qbittorrent-nox built from source on the shared Alpine base, rootless from
# the first process. Follows the official docker-qbittorrent-nox recipe
# (static libtorrent, Qt from Alpine packages); libtorrent 1.2 is the default
# because the deployments that consume this image are seed-heavy. The 1.2 line
# still uses boost::asio::io_service, which Boost removed in 1.87, so Boost
# stays on 1.86 until the libtorrent 2 line is adopted.
FROM ghcr.io/rake-pro/alpine-base:1.0@sha256:590afe2799b4dc11d5d9263cb383d68f2813d1b454ded2b5b1c6e89cb6fa645f AS build
ARG VERSION="5.3.0"
ARG LIBTORRENT_TAG="v1.2.20"
ARG BOOST_VERSION="1.86.0"

RUN apk add --no-cache \
        cmake \
        curl \
        g++ \
        git \
        make \
        ninja \
        openssl-dev \
        qt6-qtbase-dev \
        qt6-qtbase-private-dev \
        qt6-qttools-dev \
        zlib-dev

# Same hardening flags as the official image.
ENV CFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
    CXXFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
    LDFLAGS="-gz -Wl,-O1,--as-needed,--sort-common,-z,now,-z,pack-relative-relocs,-z,relro"

WORKDIR /src

# Boost headers only.
RUN curl -fsSL -o boost.tar.gz \
        "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_$(printf '%s' "${BOOST_VERSION}" | tr . _).tar.gz" \
    && tar -xzf boost.tar.gz \
    && mv boost_* boost \
    && rm boost.tar.gz \
    && cd boost \
    && ./bootstrap.sh \
    && ./b2 stage --stagedir=./ --with-headers

# libtorrent, static.
RUN git clone --branch "${LIBTORRENT_TAG}" --depth 1 --recurse-submodules https://github.com/arvidn/libtorrent.git \
    && cd libtorrent \
    && cmake -B build -G Ninja \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
        -DBOOST_ROOT=/src/boost/lib/cmake \
        -Ddeprecated-functions=OFF \
    && cmake --build build -j "$(nproc)" \
    && cmake --install build

# qBittorrent (headless).
RUN curl -fsSL -o qbt.tar.gz "https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-${VERSION}.tar.gz" \
    && tar -xzf qbt.tar.gz \
    && rm qbt.tar.gz \
    && cd "qBittorrent-release-${VERSION}" \
    && cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
        -DBOOST_ROOT=/src/boost/lib/cmake \
        -DGUI=OFF \
    && cmake --build build -j "$(nproc)" \
    && cmake --install build \
    && printf 'qbittorrent-nox build inputs\n\nboost %s\nlibtorrent-rasterbar git %s (%s)\nqBittorrent %s\n\n' \
        "${BOOST_VERSION}" "$(git -C /src/libtorrent rev-parse HEAD)" "${LIBTORRENT_TAG}" "${VERSION}" > /sbom.txt \
    && apk list -I | sort >> /sbom.txt

FROM ghcr.io/rake-pro/alpine-base:1.0@sha256:590afe2799b4dc11d5d9263cb383d68f2813d1b454ded2b5b1c6e89cb6fa645f
ARG VERSION
LABEL org.opencontainers.image.source="https://github.com/Rake-Pro/qbittorrent-nox" \
      org.opencontainers.image.version="${VERSION}"

# Config and data under /config (qBittorrent/qBittorrent.conf, same layout as
# the previous image). WEBUI_PORT and TORRENTING_PORT are read by the entrypoint.
ENV HOME="/config" \
    XDG_CONFIG_HOME="/config" \
    XDG_DATA_HOME="/config" \
    QBT_CONFIRM_LEGAL_NOTICE=1 \
    WEBUI_PORT=8080

RUN apk add --no-cache \
        7zip \
        libcrypto3 \
        libssl3 \
        python3 \
        qt6-qtbase \
        qt6-qtbase-sqlite \
        zlib

COPY --from=build /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox
COPY --from=build /sbom.txt /sbom.txt
COPY --chmod=0755 entrypoint.sh /entrypoint.sh

USER 65534:65534
WORKDIR /config
VOLUME ["/config"]
EXPOSE 8080 6881 6881/udp

ENTRYPOINT ["/usr/bin/catatonit", "--", "/entrypoint.sh"]
