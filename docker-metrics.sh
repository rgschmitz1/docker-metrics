#!/bin/sh

cleanup() {
	local tmp=$(mktemp)
	sed -i '$s/,//' $LOG
	echo ']}' | tee -a $LOG
	jq -cM $LOG > $tmp || exit $?
	mv $tmp $LOG
}

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
echo '{"workflow": "'${WORKFLOW}'", "data": [' | tee $LOG
while [ ! -f /tmp/output/metrics ]; do
	echo '{"datetime": "'$(date +%s)'", "stats": [' | tee -a $LOG
	docker stats --no-stream --format "{{json . }}" | tee -a $LOG
	echo ']},' | tee -a $LOG
done

cleanup
