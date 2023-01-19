#!/bin/sh

usage() {
	cat <<-_USAGE
	Usage: $(basename $0) [workflow]

	Collects stats from docker until trigger variable is detected
	_USAGE
	exit $1
}

[ -n "$1" ] && WORKFLOW="$1" || usage 1

LOG="/data/logs"
mkdir -p $LOG || exit 1
LOG="$LOG/$(date '+%Y%m%d-%H%M%S')${WORKFLOW}-metrics.log"

# Generate log
echo '{"workflow": "'${WORKFLOW}'", "data": [' > $LOG
while true; do
	echo '{"datetime": "'$(date '+%Y%m%d-%H%M%S')'", "stats": [' >> $LOG
	docker stats --no-stream --format "{{json . }}" >> $LOG
	echo ']}' >> $LOG
done
echo ']}' >> $LOG
