#!/bin/sh

set -e

[ -z "$IPSET_BIN" ] && IPSET_BIN=ipset

CMD=$(cat <<EOF
for x in \$(seq 0 127); do
    echo "create h\$x hash:ip"
    echo "create l\$x list:set timeout 10 comment"
done | $IPSET_BIN restore
for x in \$(seq 0 127); do
    for y in \$(seq 0 127); do
        echo "add l\$x h\$y timeout 1000 comment \"l\$x h\$y\""
    done
done | $IPSET_BIN restore
# Wait for GC
sleep 15
EOF
)

unshare_ok=no

# Check if user namespaces and remapped-root is supported.
options="-Urn"
if ! unshare -n "$options" ls > /dev/null 2>&1;then
	options="-n"
fi

if ! unshare "$options" bash -c "$CMD"; then
	# Either network namespaces are not
	# supported at all or $CMD is failing.
	echo "unshare $options bash -c failed"
	exit 1
fi

parallel=16
for x in $(seq 1 123); do
    unshare "$options" bash -c "$CMD" &

    [ $((x % $parallel)) -eq 0 ] && wait
done

wait
