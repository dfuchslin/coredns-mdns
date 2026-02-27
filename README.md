```
                        _                               _
  ___ ___  _ __ ___  __| |_ __  ___       _ __ ___   __| |_ __  ___
 / __/ _ \| '__/ _ \/ _` | '_ \/ __|_____| '_ ` _ \ / _` | '_ \/ __|
| (_| (_) | | |  __/ (_| | | | \__ \_____| | | | | | (_| | | | \__ \
 \___\___/|_|  \___|\__,_|_| |_|___/     |_| |_| |_|\__,_|_| |_|___/
```

# coredns-mdns

A DNS to mDNS bridge using coredns, avahi2dns, and avahi-daemon.

Bare hostname queries will be tried to be resolved by mdns, by appending '.local'.
Hostnames ending in .local will be tried to be resolved by mdns.
Other hostnames will be forwarded to the upstream resolver.

The image publish workflow was heavily inspired by [blake c's external-mdns project](https://github.com/blake/external-mdns).


## Usage

`docker-compose.yaml`
```
services:
  coredns:
    container_name: coredns-mdns
    image: ghcr.io/dfuchslin/coredns-mdns:main
    restart: unless-stopped
    network_mode: host
    privileged: true
    volumes:
      - ./Corefile:/etc/coredns/Corefile
    env:
      COREDNS_CONFIG: /etc/coredns/Corefile

```

```
cat Corefile

. {
    log
    errors
    cache 30
    forward . 9.9.9.9
}

local {
    mdns
    cache 10
}
```
