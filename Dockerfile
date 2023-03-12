# syntax=docker/dockerfile:1

# bump: dav1d /DAV1D_VERSION=([\d.]+)/ https://code.videolan.org/videolan/dav1d.git|*
# bump: dav1d after ./hashupdate Dockerfile DAV1D $LATEST
# bump: dav1d link "Release notes" https://code.videolan.org/videolan/dav1d/-/tags/$LATEST
ARG DAV1D_VERSION=1.1.0
ARG DAV1D_URL="https://code.videolan.org/videolan/dav1d/-/archive/$DAV1D_VERSION/dav1d-$DAV1D_VERSION.tar.gz"
ARG DAV1D_SHA256=b163791a587c083803a3db2cd18b4fbaf7fb865b47d038c4869ffef7722b6b16

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG DAV1D_URL
ARG DAV1D_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O dav1d.tar.gz "$DAV1D_URL" && \
  echo "$DAV1D_SHA256  dav1d.tar.gz" | sha256sum --status -c - && \
  mkdir dav1d && \
  tar xf dav1d.tar.gz -C dav1d --strip-components=1 && \
  rm dav1d.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/dav1d/ /tmp/dav1d/
WORKDIR /tmp/dav1d
RUN \
  apk add --no-cache --virtual build \
    build-base meson ninja nasm pkgconf && \
  meson build --buildtype release -Ddefault_library=static && \
  ninja -j$(nproc) -C build install && \
  # Sanity tests
  pkg-config --exists --modversion --path dav1d && \
  ar -t /usr/local/lib/libdav1d.a && \
  readelf -h /usr/local/lib/libdav1d.a && \
  # Cleanup
  apk del build

FROM scratch
ARG DAV1D_VERSION
COPY --from=build /usr/local/lib/pkgconfig/dav1d.pc /usr/local/lib/pkgconfig/dav1d.pc
COPY --from=build /usr/local/lib/libdav1d.a /usr/local/lib/libdav1d.a
COPY --from=build /usr/local/include/dav1d/ /usr/local/include/dav1d/
