# Purpose
Creates metrics logs from workflows in docker. Logs are JSON formatted for easy parsing.

# Usage
```
Usage: docker-metrics.sh <workflow>

Collects metrics from 'docker stats' until '<LOG_DIR>/halt-<workflow>-metrics' is detected

Required positional argument:
  workflow     - name of the workflow (used in log filename)

Optional environment variables:
  STOP_METRICS - When not empty, generate halt signal file then exit
  LOG_DIR      - Directory to store JSON logs, default is '/data/logs'
```

# Output
`<LOG_DIR>/<YYYYMMDD-HHMMSS>-<workflow>-metrics.log`
