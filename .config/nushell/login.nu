open /etc/locale.conf
| lines
| parse "{name}={value}"
| str trim value --char '"'
| transpose --header-row --as-record
| load-env
