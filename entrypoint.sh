#!/bin/ash
set -euo pipefail

echo "=== Starting mDNS → DNS bridge container ==="

############################################
# Runtime preparation
############################################

mkdir -p /run/dbus
mkdir -p /var/run/dbus

# Ensure machine-id exists
if [ ! -f /etc/machine-id ]; then
    echo "Generating machine-id..."
    dbus-uuidgen > /etc/machine-id
fi

############################################
# Start DBus (system bus)
############################################

echo "Starting dbus-daemon..."
dbus-daemon --system --nofork --nopidfile &
DBUS_PID=$!

echo "Waiting for DBus to become responsive..."

for i in $(seq 1 50); do
    if dbus-send --system \
        --dest=org.freedesktop.DBus \
        --type=method_call \
        --print-reply \
        /org/freedesktop/DBus \
        org.freedesktop.DBus.ListNames \
        >/dev/null 2>&1; then
        break
    fi
    sleep 0.2
done

if ! dbus-send --system \
    --dest=org.freedesktop.DBus \
    --type=method_call \
    --print-reply \
    /org/freedesktop/DBus \
    org.freedesktop.DBus.ListNames \
    >/dev/null 2>&1; then
    echo "ERROR: DBus not responding"
    exit 1
fi

echo "DBus ready."

############################################
# Start Avahi
############################################

echo "Starting avahi-daemon..."
avahi-daemon --no-chroot --debug &
AVAHI_PID=$!

# Wait for Avahi to register on DBus
echo "Waiting for Avahi to become available..."
for i in $(seq 1 50); do
    if busctl --system list 2>/dev/null | grep -q org.freedesktop.Avahi; then
        break
    fi
    sleep 0.2
done

if ! busctl --system list 2>/dev/null | grep -q org.freedesktop.Avahi; then
    echo "ERROR: Avahi did not register on DBus"
    exit 1
fi

echo "Avahi ready."

############################################
# Start avahi2dns
############################################

echo "Starting avahi2dns..."
avahi2dns --debug --port $AVAHI2DNS_BIND_PORT --addr $AVAHI2DNS_BIND_ADDRESS &
A2D_PID=$!

############################################
# Graceful shutdown handling
############################################

shutdown() {
    echo "Shutting down services..."
    kill -TERM "$A2D_PID" 2>/dev/null || true
    kill -TERM "$AVAHI_PID" 2>/dev/null || true
    kill -TERM "$DBUS_PID" 2>/dev/null || true
    wait
    exit 0
}

trap shutdown SIGTERM SIGINT

############################################
# Start CoreDNS (foreground)
############################################

echo "Starting CoreDNS..."
exec coredns -conf $COREDNS_CONFIG
