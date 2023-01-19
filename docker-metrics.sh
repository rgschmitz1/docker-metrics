#!/bin/sh

usage() {
	cat <<-_USAGE
	Usage: $(basename $0) [workflow]

	Collects stats from docker until trigger variable is detected
	_USAGE
	exit $1
}

WORKFLOW="$1"
if [ -z "$WORKFLOW" ]; then
	usage 1
fi

LOG="/data/${WORKFLOW}-metrics.log"

echo {"workflow": \"${WORKFLOW}\", "data": [ > $LOG
