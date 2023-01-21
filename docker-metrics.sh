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

	# Memory stats
	TOTAL_MEM_USAGE=0
	MAX_MEM_USAGE=0

	# CPU stats
	TOTAL_CPU_USAGE=0
	MAX_CPU_USAGE=0

	# Generate log
	generate

	# Clean/minify log and remove trigger file
	cleanup
}

evaluate_stats() {
	let ITERATIONS++

	local temp_mem_sum=0
	for mem in $(jq -r '.MemUsage | split(" ")[0]' $TEMP_JSON | tr -d 'B'); do
		local mem_in_bytes=$(numfmt --from=auto $mem)
		temp_mem_sum=$(echo "$mem_in_bytes + $temp_mem_sum" | bc)
	done
	TOTAL_MEM_USAGE=$(echo "$TOTAL_MEM_USAGE + $temp_mem_sum" | bc)
	[ $temp_mem_sum -gt $MAX_MEM_USAGE ] && MAX_MEM_USAGE=$temp_mem_sum

	local temp_cpu_sum=0
	for cpu in $(jq -r '.CPUPerc' $TEMP_JSON | tr -d '%'); do
		temp_cpu_sum=$(echo "$cpu + $temp_cpu_sum" | bc)
	done
	TOTAL_CPU_USAGE=$(echo "$temp_cpu_sum + $TOTAL_CPU_USAGE" | bc)
	[ $(echo "$temp_cpu_sum > $MAX_CPU_USAGE" | bc) -eq 1 ] && \
		MAX_CPU_USAGE=$temp_cpu_sum
}

usage() {
	cat <<-_USAGE
	Usage: $(basename $0) [workflow]

	Collects stats from docker until '$TRIGGER' is detected
	_USAGE
	exit $1
}

cleanup() {
	rm -f $TRIGGER $TEMP_JSON
	sed -i '$s/,$//' $LOG
	MAX_MEM_USAGE=$(numfmt -to=iec $MAX_MEM_USAGE)
	AVG_MEM_USAGE=$(echo "$TOTAL_MEM_USAGE / $ITERATIONS" | bc)
	AVG_MEM_USAGE=$(numfmt -to=iec $AVG_MEM_USAGE)
	AVG_CPU_USAGE=$(echo "scale=2;$TOTAL_MEM_USAGE / $ITERATIONS" | bc)
	cat <<-_EOF >> $LOG
	],
	"max_mem_usage": "$MAX_MEM_USAGE",
	"avg_mem_usage": "$AVG_MEM_USAGE",
	"max_cpu_usage": "${MAX_CPU_USAGE}%",
	"avg_cpu_usage": "${AVG_CPU_USAGE}%"
	}
	_EOF
	local tmp=$(mktemp)
	jq -cM . $LOG > $tmp || exit $?
	mv $tmp $LOG
}

generate_log() {
	echo '{"workflow": "'${WORKFLOW}'", "data": [' > $LOG
	TEMP_JSON=$(mktemp)
	while [ ! -f $TRIGGER ]; do
		echo '{"datetime": "'$(date +%s)'", "stats": [' >> $LOG
		docker stats --no-stream --format "{{json . }}" > $TEMP_JSON
		sed 's/$/,/; $s/,$//' $TEMP_JSON | tee -a $LOG
		evaluate_stats
		echo ']},' >> $LOG
	done
}

main "$*"
