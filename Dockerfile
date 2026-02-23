ARG GOLANG_IMAGE=golang:1.26.0
ARG DEBIAN_IMAGE=debian:stable-slim
ARG BASE=gcr.io/distroless/static-debian12:nonroot

FROM --platform=$BUILDPLATFORM ${GOLANG_IMAGE} AS gobuild
ARG COREDNS_VERSION=1.14.1
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /go/src/github.com/coredns
RUN curl -fLO https://github.com/coredns/coredns/archive/refs/tags/v${COREDNS_VERSION}.tar.gz && \
    tar -xzf v${COREDNS_VERSION}.tar.gz && \
    mv coredns-${COREDNS_VERSION} coredns && \
    cd coredns && \
    if ! grep -q "mdns" plugin.cfg; then \
        sed -i '$a mdns:github.com/openshift/coredns-mdns' plugin.cfg; \
    fi && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=$(echo ${TARGETVARIANT} | cut -c2) \
    go build -o /coredns .


FROM --platform=$BUILDPLATFORM ${DEBIAN_IMAGE} AS build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update \
    && apt-get -qq --no-install-recommends install libcap2-bin
COPY --from=gobuild /coredns /coredns
RUN setcap cap_net_bind_service=+ep /coredns

FROM ${BASE}
COPY --from=build /coredns /coredns
USER nonroot:nonroot
# Reset the working directory inherited from the base image back to the expected default:
# https://github.com/coredns/coredns/issues/7009#issuecomment-3124851608
WORKDIR /
EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
