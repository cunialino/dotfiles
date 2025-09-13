# System Requirements

Here I keep my system level requirments.

As of now, I am working on Void Linux, hence the package manager is [xbps package manager](https://docs.voidlinux.org/xbps/index.html).

- bluez: bluetooth stuff, needs service
- chrony: time sync utils, needs service
- dhcp
- dhcpcd
- dosfstools: honestly... only god nkows what this is for
- efibootmgr
- light: wayland light (maybe can be moved to hm)
- seatd
- socklog-void
- turnstile: this is useful to set a bunch of vars we need everywhere
- ufw: firewall (use this to allow only machines in the same vpn to get in)
