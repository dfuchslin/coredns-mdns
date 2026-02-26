#!/bin/ash
set -e

# Ensure runtime dirs
mkdir -p /run/dbus
mkdir -p /var/run/dbus

# Generate machine-id (required for system bus)
if [ ! -f /etc/machine-id ]; then
    dbus-uuidgen > /etc/machine-id
fi

# Start dbus system bus
dbus-daemon --system --nofork --nopidfile &
DBUS_PID=$!

# Start avahi
avahi-daemon --no-chroot --debug &
AVAHI_PID=$!

# Start avahi2dns
avahi2dns --debug --port $AVAHI2DNS_BIND_PORT --addr $AVAHI2DNS_BIND_ADDRESS &
A2D_PID=$!

# Start coredns
exec coredns -conf $COREDNS_CONFIG
