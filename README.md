```
                        _                               _
  ___ ___  _ __ ___  __| |_ __  ___       _ __ ___   __| |_ __  ___
 / __/ _ \| '__/ _ \/ _` | '_ \/ __|_____| '_ ` _ \ / _` | '_ \/ __|
| (_| (_) | | |  __/ (_| | | | \__ \_____| | | | | | (_| | | | \__ \
 \___\___/|_|  \___|\__,_|_| |_|___/     |_| |_| |_|\__,_|_| |_|___/
```

# coredns-mdns

Builds a docker image with [coredns](https://coredns.io/) and the [mdns plugin](https://coredns.io/explugins/mdns/) enabled for service discovery.

Uses the [Dockerfile from coredns](https://github.com/coredns/coredns/blob/master/Dockerfile) but adds a step to download the go source for the specified version, add mdns to the list of plugins, and compile for the correct architecture.

CI and image publish workflows were heavily inspired by [blake c's external-mdns project](https://github.com/blake/external-mdns).
