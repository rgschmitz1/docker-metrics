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
The widget must be used in a pair, that is a ***start*** and ***stop*** widget.
* The widget should be started via a 'trigger' input.
* The widget should be stopped via another docker-metrics widget only, clicking the 'stop' button will result in a broken json log.
* The difference between the start and stop metrics collection is that ***'Trigger/Stop metrics collection'*** option is selected under requirements (see below)
![image](https://user-images.githubusercontent.com/14095796/215690415-834be0a8-77dc-4e28-929a-bf9331fceecc.png)

> **NOTE:** the inputs ***workflow name*** and ***log directory*** must be consistent between the pair of docker-metrics widgets.

# Demo
Watch a demo below.

https://user-images.githubusercontent.com/14095796/215687523-de18f5c8-67e1-48ee-93f7-dccf86e5fde0.mp4

# Output
`<LOG_DIR>/<YYYYMMDD-HHMMSS>-<workflow>-metrics.log`
