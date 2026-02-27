FROM alpine:edge AS base

RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache openrc avahi2dns@testing avahi2dns-openrc@testing dbus avahi coredns

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
    sed -i '3a\start_stop_daemon_args="--stdout /proc/1/fd/1 --stderr /proc/1/fd/2"' /etc/init.d/avahi2dns

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
    sed -i '5a\start_stop_daemon_args="--stdout /proc/1/fd/1 --stderr /proc/1/fd/2"' /etc/init.d/avahi-daemon

# --- dbus ---
# Remove --syslog-only so dbus logs go to stderr (captured by start-stop-daemon).
# Redirect to Docker stdout/stderr via output_log/error_log.
RUN sed -i 's/--syslog-only //' /etc/init.d/dbus
RUN printf 'output_logger=""\nerror_logger=""\noutput_log="/proc/1/fd/1"\nerror_log="/proc/1/fd/2"\n' > /etc/conf.d/dbus

# --- coredns ---
# The packaged init script uses supervise-daemon and logs to /var/log/coredns/.
# Fix: run as root (we're in Docker), log to /proc/1/fd/{1,2} so Docker captures it,
# and run in foreground.
RUN sed -i \
    -e 's/^command_user=.*/command_user="root"/' \
    -e 's|^start_stop_daemon_args=.*|start_stop_daemon_args="--stdout /proc/1/fd/1 --stderr /proc/1/fd/2"|' \
    -e '/^[[:space:]]*--stderr/d' \
    -e 's/^capabilities=.*/# capabilities removed for Docker/' \
    -e 's/after net/after net\n\tneed avahi2dns/' \
    /etc/init.d/coredns
# conf.d: keep extra args empty (logging is via Corefile 'log' plugin)
RUN sed -i 's/^COREDNS_EXTRA_ARGS=.*/COREDNS_EXTRA_ARGS=""/' /etc/conf.d/coredns

RUN rc-update add dbus && rc-update add avahi-daemon && rc-update add avahi2dns && rc-update add coredns

ENV COREDNS_CONFIG=/etc/coredns/Corefile
# CORENDS_EXTRA_ARGS misspelled (defined in the alpine coredns package)
ENV CORENDS_EXTRA_ARGS=""

CMD ["/sbin/init"]
