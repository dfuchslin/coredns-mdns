FROM alpine:edge AS base

RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache openrc avahi2dns@testing avahi2dns-openrc@testing dbus avahi coredns

RUN sed -i 's/^\(tty\d\:\:\)/#\1/g' /etc/inittab && \
  sed -i \
  -e 's/#rc_sys=".*"/rc_sys="docker"/g' \
  -e 's/#rc_env_allow=".*"/rc_env_allow="\*"/g' \
  -e 's/#rc_crashed_stop=.*/rc_crashed_stop=NO/g' \
  -e 's/#rc_crashed_start=.*/rc_crashed_start=YES/g' \
  -e 's/#rc_provide=".*"/rc_provide="loopback net"/g' \
  -e 's/#rc_logger="YES"/rc_logger="NO"/' \
  /etc/rc.conf && \
  rm -f /etc/init.d/hwdrivers \
  /etc/init.d/hwclock \
  /etc/init.d/hwdrivers \
  /etc/init.d/modules \
  /etc/init.d/modules-load \
  /etc/init.d/modloop \
RUN echo 'command_args="--debug --port 5454 --addr 0.0.0.0"' > /etc/conf.d/avahi2dns && \
    echo 'output_logger=""' >> /etc/init.d/avahi2dns && \
    echo 'error_logger=""' >> /etc/init.d/avahi2dns
RUN echo 'command_args="--no-chroot --debug"' > /etc/conf.d/avahi-daemon && \
    echo 'output_logger=""' >> /etc/conf.d/avahi-daemon && \
    echo 'error_logger=""' >> /etc/conf.d/avahi-daemon && \
    sed -i 's/#debug=no/debug=yes/' /etc/avahi/avahi-daemon.conf
RUN echo 'command_args="--nofork --nopidfile"' > /etc/conf.d/dbus && \
    echo 'output_logger=""' >> /etc/init.d/dbus && \
    echo 'error_logger=""' >> /etc/init.d/dbus
RUN rc-update add dbus && rc-update add avahi-daemon && rc-update add avahi2dns && rc-update add coredns

#COPY entrypoint.sh /bin/entrypoint.sh
#RUN chmod +x /bin/entrypoint.sh

ENV COREDNS_CONFIG=/etc/coredns/Corefile
ENV CORENDS_EXTRA_ARGS=""

CMD ["/sbin/init"]
