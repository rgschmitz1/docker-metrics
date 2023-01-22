#!/bin/sh

trap cleanup 2

#
# Docker metrics collector
#
# Author: Bob Schmitz
#

#
# Main function
#
# Required parameter:
#   $1 - Workflow name
#
# Optional environment variables:
#   LOG_DIR     - directory to store metrics, defaults to '/data/logs'
#   HALT_SIGNAL - creates a file to terminate metrics collection
#
main() {
	# Check if workflow name is set, otherwise print usage and exit
	if [ -z "$1" ]; then
		usage
		exit 1
	fi

	# Workflow name
	WORKFLOW="$1"

	# Check if log directory is set
	[ -z "$LOG_DIR" ] && LOG_DIR="/data/logs"

	# Create log directory if necessary
	mkdir -p $LOG_DIR || exit 1

	# Halt signal file
	HALT_SIGNAL="$LOG_DIR/halt-${WORKFLOW}-metrics"

	# Check if STOP_METRICS variable is set
	if [ -n "$STOP_METRICS" ]; then
		touch $HALT_SIGNAL
		exit 0
	fi

	# Start workflow
	START_TIME=$(date '+%s')

	# Log filename
	LOG="$LOG_DIR/$(date -d @${START_TIME} '+%Y%m%d-%H%M%S')-${WORKFLOW}-metrics.log"

	# CPU stats
	CPU_TOTAL_USAGE=0
	CPU_MAX_USAGE=0

	# Memory stats
	MEM_TOTAL_USAGE=0
	MEM_MAX_USAGE=0

	# Generate JSON log
	TEMP_JSON=$(mktemp)
	generate_log || exit 1

	# Clean/minify log and remove extraneous files
	cleanup
}

#
# Output the script usage
#
usage() {
	cat <<-_USAGE
	Usage: $(basename $0) <workflow>

	Collects metrics from 'docker stats' until '<LOG_DIR>/halt-<workflow>-metrics' is detected

	Required positional argument:
	  workflow	: name of the workflow (used in log filename)

	Optional environment variables:
	  STOP_METRICS	: When not empty, generate halt signal file then exit
	  LOG_DIR	: Directory to store JSON logs, default is '/data/logs'
	_USAGE
}

#
# Calculate the workflow runtime
#
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

#
# Cleanup temporary files and finish the creating/compacting the JSON log
#
cleanup() {
	# Capture total runtime
	runtime

	# Remove temporary files
	rm -f $HALT_SIGNAL

	# Verify JSON log exists or exit with error status
	[ ! -f "$LOG" ] && exit 1

	# Remove extra comma at the end of the log if it exists
	sed -i '$s/,$//' $LOG

	# Evaluate CPU stats
	CPU_AVG_USAGE=$(echo "scale=2;$CPU_TOTAL_USAGE / $ITERATIONS" | bc)

	# Evaluate and format memory stats
	MEM_AVG_USAGE=$(echo "$MEM_TOTAL_USAGE / $ITERATIONS" | bc)
	MEM_AVG_USAGE=$(numfmt --to=iec-i --format='%.2f' $MEM_AVG_USAGE)

	MEM_MAX_USAGE=$(numfmt --to=iec-i --format='%.2f' $MEM_MAX_USAGE)

	# Append extra data to JSON log
	tee -a $LOG <<-_EOF
	],
	"stats": [
	  "cpu_avg_usage": "$CPU_AVG_USAGE%",
	  "cpu_max_usage": "$CPU_MAX_USAGE%"
	  "mem_avg_usage": "$MEM_AVG_USAGE",
	  "mem_max_usage": "$MEM_MAX_USAGE",
	  "runtime": "$RUNTIME"
	],
	"workflow": "$WORKFLOW"
	}
	_EOF

	# Compact JSON log
	jq -cSM . $LOG > $TEMP_JSON || exit $?
	mv $TEMP_JSON $LOG
	exit $?
}

#
# Evaluate memory and CPU usage
#
evaluate_stats() {
	let ITERATIONS++

	# Memory stats
	local temp_mem_sum=0
	for mem in $(jq -r '.MemUsage | split(" ")[0]' $TEMP_JSON | tr -d 'B'); do
		local mem_in_bytes=$(numfmt --from=auto $mem)
		temp_mem_sum=$(echo "$mem_in_bytes + $temp_mem_sum" | bc)
	done
	MEM_TOTAL_USAGE=$(echo "$MEM_TOTAL_USAGE + $temp_mem_sum" | bc)
	[ $temp_mem_sum -gt $MEM_MAX_USAGE ] && MEM_MAX_USAGE=$temp_mem_sum

	# CPU stats
	local temp_cpu_sum=0
	for cpu in $(jq -r '.CPUPerc' $TEMP_JSON | tr -d '%'); do
		temp_cpu_sum=$(echo "$cpu + $temp_cpu_sum" | bc)
	done
	CPU_TOTAL_USAGE=$(echo "$temp_cpu_sum + $CPU_TOTAL_USAGE" | bc)
	[ $(echo "$temp_cpu_sum > $CPU_MAX_USAGE" | bc) -eq 1 ] && \
		CPU_MAX_USAGE=$temp_cpu_sum
}

#
# Write to JSON log file
#
generate_log() {
	echo '{"data": [' | tee $LOG

	# While trigger file does not exist, continously collect docker stats
	while [ ! -f "$HALT_SIGNAL" ]; do
		docker stats --no-stream --format \
			'{"BlockIO": "{{.BlockIO}}", "CPUPerc": "{{.CPUPerc}}", "MemUsage": "{{.MemUsage}}", "Name": "{{.Name}}", "NetIO": "{{.NetIO}}", "PIDs": "{{.PIDs}}"}' \
			> $TEMP_JSON
		if [ ! -s "$TEMP_JSON" ]; then
			echo "$TEMP_JSON is empty, something went wrong!"
			return 1
		fi
		# Insert '{"stats": [' at the beginning of first line in the file,
		# add a comma to the end of every line,
		# replace the comma at the end of the last line of the file with a '],'
		sed '1s/^/{"metrics": [/; s/$/,/; $s/,$/],/' $TEMP_JSON | tee -a $LOG
		echo '"time": "'$(date '+%s')'"},' | tee -a $LOG
		evaluate_stats
	done
}

main "$*"
