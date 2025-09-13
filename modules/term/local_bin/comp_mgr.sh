#!/bin/bash
#
# Start a composition manager.
# (xcompmgr in this case)

comphelp() {
    echo "Composition Manager:"
    echo "   (re)start: COMP"
    echo "   stop:      COMP -s"
    echo "   query:     COMP -q"
    echo "              returns 0 if composition manager is running, else 1"
    exit
}

checkcomp() {
    pgrep xcompmgr &>/dev/null
}

stopcomp() {
    checkcomp && killall xcompmgr
}

startcomp() {
    stopcomp
    # Example settings only. Replace with your own.
    xcompmgr -CcfF -I-.015 -O-.03 -D6 -t-1 -l-3 -r4.2 -o.5 &
    exit
}
togglecomp(){
    if pgrep xcompmgr &>/dev/null; then
        echo "Turning xcompmgr OFF"
        pkill xcompmgr &
    else
        echo "Turning xcompmgr ON"
        xcompmgr -c -C -t-5 -l-5 -r4.2 -o.55 &
    fi
}

case "$1" in
    "")   startcomp ;;
    "-t") togglecomp ;;
    "-s") stopcomp; exit ;;
    *)    comphelp ;;
esac
