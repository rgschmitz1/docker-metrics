# Purpose
Creates metrics logs from workflows in docker. Logs are JSON formatted for easy parsing.

# Usage
```
Usage: docker-metrics.sh <workflow>

Collects metrics from 'docker stats' until '$HALT_SIGNAL' is detected

Required positional argument:
  workflow\t- name of the workflow (used in log filename)

Optional environment variables:
  STOP_METRICS - Generate halt signal file then exit
  HALT_SIGNAL - Temporary file used to halt metrics collection
                (defaults to '/data/stop_metrics')
  LOG_DIR - Directory to store JSON logs
```

# Output
`/data/logs/<YYYYMMDD-HHMMSS>-<workflow>-metrics.log`
