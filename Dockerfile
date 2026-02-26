FROM alpine:edge

RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

RUN apk add --no-cache \
    dbus \
    avahi \
    avahi2dns@testing \
    coredns \
    tini

COPY entrypoint.sh /bin/entrypoint.sh
RUN chmod +x /bin/entrypoint.sh

ENV COREDNS_CONFIG=/etc/coredns/Corefile
ENV AVAHI2DNS_BIND_PORT=5454
ENV AVAHI2DNS_BIND_ADDRESS=0.0.0.0

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/bin/entrypoint.sh"]
