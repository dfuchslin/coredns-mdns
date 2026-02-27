FROM --platform=$BUILDPLATFORM golang:1.26.0 AS gobuild
ARG COREDNS_VERSION=1.14.1
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /go/src/github.com/coredns
RUN curl -fLO https://github.com/coredns/coredns/archive/refs/tags/v${COREDNS_VERSION}.tar.gz && \
    tar -xzf v${COREDNS_VERSION}.tar.gz && \
    mv coredns-${COREDNS_VERSION} coredns && \
    cd coredns && \
    if ! grep -q "alternate:" plugin.cfg; then \
    sed -i '/^forward:forward$/i alternate:github.com/coredns/alternate' plugin.cfg; \
    fi && \
    go get github.com/coredns/alternate && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=$(echo ${TARGETVARIANT} | cut -c2) go generate && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=$(echo ${TARGETVARIANT} | cut -c2) go build -o /coredns .

FROM alpine:edge AS base

RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache openrc avahi2dns@testing avahi2dns-openrc@testing dbus avahi libcap-setcap

# --- OpenRC Docker adjustments ---
RUN sed -i 's/^\(tty\d\:\:\)/#\1/g' /etc/inittab && \
    sed -i \
    -e 's/#rc_sys=".*"/rc_sys="docker"/g' \
    -e 's/#rc_env_allow=".*"/rc_env_allow="\*"/g' \
    -e 's/#rc_crashed_stop=.*/rc_crashed_stop=NO/g' \
    -e 's/#rc_crashed_start=.*/rc_crashed_start=YES/g' \
    -e 's/#rc_provide=".*"/rc_provide="loopback net dev"/g' \
    /etc/rc.conf && \
    rm -f /etc/init.d/hwdrivers \
    /etc/init.d/hwclock \
    /etc/init.d/modules \
    /etc/init.d/modules-load \
    /etc/init.d/modloop

# --- avahi2dns ---
# conf.d: set CLI args (debug + listen port)
# init.d: use supervise-daemon so it backgrounds while logging to Docker stdout
RUN echo 'command_args="--debug --port 5454 --addr 0.0.0.0"' > /etc/conf.d/avahi2dns
RUN sed -i \
    -e '/^command_background=/d' \
    -e '/^output_logger=/d' \
    -e '/^error_logger=/d' \
    -e '/^pidfile=/d' \
    /etc/init.d/avahi2dns
RUN sed -i '1a\supervisor="supervise-daemon"' /etc/init.d/avahi2dns && \
    sed -i '2a\pidfile="/run/avahi2dns.pid"' /etc/init.d/avahi2dns && \
    sed -i '3a\output_log="/proc/1/fd/1"' /etc/init.d/avahi2dns && \
    sed -i '4a\error_log="/proc/1/fd/2"' /etc/init.d/avahi2dns

# --- avahi-daemon ---
# The packaged init script hardcodes "avahi-daemon -D" in a custom start() and
# "avahi-daemon -k" in stop(), ignoring conf.d entirely. Remove those custom
# functions and add supervise-daemon variables so OpenRC manages the process.
RUN sed -i \
    -e '/^start()/,/^}/d' \
    -e '/^stop()/,/^}/d' \
    /etc/init.d/avahi-daemon
RUN sed -i '1a\supervisor="supervise-daemon"' /etc/init.d/avahi-daemon && \
    sed -i '2a\command="/usr/sbin/avahi-daemon"' /etc/init.d/avahi-daemon && \
    sed -i '3a\command_args="--no-drop-root --no-chroot"' /etc/init.d/avahi-daemon && \
    sed -i '4a\pidfile="/run/avahi-daemon.pid"' /etc/init.d/avahi-daemon && \
    sed -i '5a\output_log="/proc/1/fd/1"' /etc/init.d/avahi-daemon && \
    sed -i '6a\error_log="/proc/1/fd/2"' /etc/init.d/avahi-daemon

# --- dbus ---
# Remove --syslog-only so dbus logs go to stderr (captured by start-stop-daemon).
# Redirect to Docker stdout/stderr via output_log/error_log.
RUN sed -i 's/--syslog-only //' /etc/init.d/dbus
RUN printf 'output_logger=""\nerror_logger=""\noutput_log="/proc/1/fd/1"\nerror_log="/proc/1/fd/2"\n' > /etc/conf.d/dbus

# --- coredns ---
# Custom-compiled CoreDNS with the alternate plugin. The Alpine coredns package
# is not installed — we COPY the binary and our own OpenRC init script.
COPY --from=gobuild /coredns /usr/bin/coredns
RUN setcap cap_net_bind_service=+ep /usr/bin/coredns
COPY coredns/coredns.initd /etc/init.d/coredns
RUN chmod +x /etc/init.d/coredns
RUN mkdir -p /etc/coredns
COPY coredns/corefile /etc/coredns/corefile

RUN rc-update add dbus && rc-update add avahi-daemon && rc-update add avahi2dns && rc-update add coredns

# Default upstream DNS — override at runtime: docker run -e UPSTREAM_DNS=10.0.0.1 ...
ENV UPSTREAM_DNS=192.168.1.1
ENV COREDNS_CONFIG=/etc/coredns/corefile

CMD ["/sbin/init"]
