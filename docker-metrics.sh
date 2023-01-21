#!/bin/sh

main() {
	# Trigger file
	TRIGGER="/data/stop_metrics"

	# Check if STOP_METRICS variable is set
	if [ -n "$STOP_METRICS" ]; then
		touch $TRIGGER
		exit 0
	fi

	# Workflow name
	WORKFLOW="$1"
	[ -z "$WORKFLOW" ] && usage 1

	# Start workflow
	START_TIME=$(date '+%s')

	# Log filename
	LOG="/data/logs"
	mkdir -p $LOG || exit 1
	LOG="$LOG/$(date -d @${START_TIME} '+%Y%m%d-%H%M%S')-${WORKFLOW}-metrics.log"

	# Memory stats
	TOTAL_MEM_USAGE=0
	MAX_MEM_USAGE=0

	# CPU stats
	TOTAL_CPU_USAGE=0
	MAX_CPU_USAGE=0

	# Generate JSON log
	TEMP_JSON=$(mktemp)
	generate_log

	# Clean/minify log and remove extraneous files
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

format_runtime() {
	END_TIME=$(date '+%s')
	RUNTIME=$(echo "$END_TIME - $START_TIME" | bc)
	local d=$(echo "$RUNTIME / 86400" | bc)
	local h=$(echo "$RUNTIME % 86400 / 3600" | bc)
	local m=$(echo "$RUNTIME % 3600 / 60" | bc)
	local s=$(echo "$RUNTIME % 60" | bc)
	RUNTIME="${d} day, ${h} hour, ${m} min, ${s} sec"
}

cleanup() {
	# Capture total runtime
	format_runtime

	# Remove temporary files
	rm -f $TRIGGER

	# Verify JSON log exists or exit with error status
	[ ! -f "$LOG" ] && exit 1

	# Cleanup and append extra data to JSON log
	sed -i '$s/,$//' $LOG

	# Evaluate and format memory stats
	MAX_MEM_USAGE=$(numfmt --to=iec $MAX_MEM_USAGE)
	AVG_MEM_USAGE=$(echo "$TOTAL_MEM_USAGE / $ITERATIONS" | bc)
	AVG_MEM_USAGE=$(numfmt --to=iec $AVG_MEM_USAGE)

	# Evaluate cpu stats
	AVG_CPU_USAGE=$(echo "scale=2;$TOTAL_CPU_USAGE / $ITERATIONS" | bc)

	cat <<-_EOF >> $LOG
	],
	"max_mem_usage": "$MAX_MEM_USAGE",
	"avg_mem_usage": "$AVG_MEM_USAGE",
	"max_cpu_usage": "${MAX_CPU_USAGE}%",
	"avg_cpu_usage": "${AVG_CPU_USAGE}%",
	"runtime": "$RUNTIME"
	}
	_EOF

	# Compact JSON log
	jq -cM . $LOG > $TEMP_JSON || exit $?
	mv $TEMP_JSON $LOG
}

generate_log() {
	echo '{"workflow": "'${WORKFLOW}'", "data": [' > $LOG

	# While trigger file does not exist, continously collect docker stats
	while [ ! -f "$TRIGGER" ]; do
		echo '{"datetime": "'$(date '+%s')'", "stats": [' >> $LOG
		docker stats --no-stream --format "{{json . }}" > $TEMP_JSON
		sed 's/$/,/; $s/,$//' $TEMP_JSON | tee -a $LOG
		evaluate_stats
		echo ']},' >> $LOG
	done
}

main "$*"
