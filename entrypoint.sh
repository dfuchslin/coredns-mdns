#!/bin/ash
set -e

# Create required runtime directories
mkdir -p /run/dbus
mkdir -p /var/run/dbus

# Start dbus in foreground
dbus-daemon --system --nofork --nopidfile &
DBUS_PID=$!

# Start avahi in foreground mode
avahi-daemon --no-chroot --debug &
AVAHI_PID=$!

# Start avahi2dns in foreground
avahi2dns --debug --port $AVAHI2DNS_BIND_PORT --addr $AVAHI2DNS_BIND_ADDRESS &
A2D_PID=$!

# Start coredns in foreground (this becomes PID 1)
exec coredns -conf $COREDNS_CONFIG
