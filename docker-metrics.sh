#!/bin/sh

main() {
	# Halt signal file
	[ -z "$HALT_SIGNAL" ] && HALT_SIGNAL="/data/stop_metrics"

	# Check if STOP_METRICS variable is set
	if [ -n "$STOP_METRICS" ]; then
		touch $HALT_SIGNAL
		exit 0
	fi

	# Workflow name
	WORKFLOW="$1"
	[ -z "$WORKFLOW" ] && usage 1

	# Start workflow
	START_TIME=$(date '+%s')

	# Check if log directory is set
	[ -z "$LOG_DIR" ] && LOG="/data/logs" || LOG="$LOG_DIR"
	mkdir -p $LOG || exit 1

	# Log filename
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
	Usage: $(basename $0) <workflow>

	Collects metrics from 'docker stats' until '$HALT_SIGNAL' is detected

	Required positional argument:
	  workflow\t- name of the workflow (used in log filename)

	Optional environment variables:
	  STOP_METRICS\t- Generate halt signal file then exit
	  HALT_SIGNAL\t- Temporary file used to halt metrics collection
	                (defaults to '/data/stop_metrics')
	  LOG_DIR\t- Directory to store JSON logs
	_USAGE
	exit $1
}

runtime() {
	RUNTIME=$(echo "$(date '+%s') - $START_TIME" | bc)
	local d=$(echo "$RUNTIME / 86400" | bc)
	local h=$(echo "$RUNTIME % 86400 / 3600" | bc)
	local m=$(echo "$RUNTIME % 3600 / 60" | bc)
	local s=$(echo "$RUNTIME % 60" | bc)

	# Format runtime
	if [ $d -gt 0 ]; then
		RUNTIME="${d} day, ${h} hour, ${m} min, ${s} sec"
	elif [ $h -gt 0 ]; then
		RUNTIME="${h} hour, ${m} min, ${s} sec"
	elif [ $m -gt 0 ]; then
		RUNTIME="${m} min, ${s} sec"
	else
		RUNTIME="${s} sec"
	fi
}

cleanup() {
	# Capture total runtime
	runtime

	# Remove temporary files
	rm -f $HALT_SIGNAL

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

	cat <<-_EOF | tee -a $LOG
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
	echo '{"workflow": "'${WORKFLOW}'", "data": [' | tee $LOG

	# While trigger file does not exist, continously collect docker stats
	while [ ! -f "$HALT_SIGNAL" ]; do
		echo '{"time": "'$(date '+%s')'", "stats": [' | tee -a $LOG
		docker stats --no-stream --format "{{json . }}" > $TEMP_JSON
		sed 's/$/,/; $s/,$/]},/' $TEMP_JSON | tee -a $LOG
		evaluate_stats
	done
}

main "$*"
