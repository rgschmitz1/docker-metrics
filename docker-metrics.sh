#!/bin/sh

main() {
	# Trigger file
	TRIGGER="/data/stop_metrics"

	# Check if STOP_METRICS variable is set
	if [ -n "$STOP_METRICS" ]; then
		touch $TRIGGER
		exit 0
	fi

	# Set workflow name
	[ -n "$1" ] && WORKFLOW="$1" || usage 1

	# Log filename
	LOG="/data/logs"
	mkdir -p $LOG || exit 1
	LOG="$LOG/$(date '+%Y%m%d-%H%M%S')${WORKFLOW}-metrics.log"

	# Generate log
	generate

	# Clean/minify log and remove trigger file
	cleanup
}

usage() {
	cat <<-_USAGE
	Usage: $(basename $0) [workflow]

	Collects stats from docker until '$TRIGGER' is detected
	_USAGE
	exit $1
}

cleanup() {
	rm -f /data/stop_metrics
	sed -i '$s/,$//' $LOG
	echo ']}' >> $LOG
	local tmp=$(mktemp)
	jq -cM . $LOG > $tmp || exit $?
	mv $tmp $LOG
}

generate() {
	echo '{"workflow": "'${WORKFLOW}'", "data": [' > $LOG
	while [ ! -f $TRIGGER ]; do
		echo '{"datetime": "'$(date +%s)'", "stats": [' >> $LOG
		docker stats --no-stream --format "{{json . }}" | sed 's/$/,/; $s/,$//' | tee -a $LOG
		echo ']},' >> $LOG
	done
}

main "$*"
