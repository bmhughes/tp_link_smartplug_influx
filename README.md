# tp_link_smartplug_influx

Ruby script to retrieve energy data from a TP Link HS110 smart plug and out it in InfluxDB Line Protocol to be called by the telegraf *exec* input plugin.

![Release](https://img.shields.io/github/release/bmhughes/tp_link_smartplug_influx.svg)
![License](https://img.shields.io/github/license/bmhughes/tp_link_smartplug_influx.svg)
[![Build Status](https://travis-ci.org/bmhughes/tp_link_smartplug_influx.svg?branch=master)](https://travis-ci.org/bmhughes/tp_link_smartplug_influx)

## Change Log

- See [CHANGELOG.md](/CHANGELOG.md) for version details and changes.

### Usage

```bash
bundle install
./influx_hs110_energy.rb
```

```bash
Usage: influx_hs110_energy.rb [options]
    -h, --help                       Prints this help
    -v, --verbose                    Enable verbose output, breaks influx line format. TESTING ONLY
    -a, --address ADDRESS            IP or FDQN of plug to poll
    -c, --config FILE                Configuration file
```

You can either specify a single host on the command line (via option `-a`) or provide multiple hosts in a configuration file in JSON format.

### Configuration File

Configuration is performed via JSON file which is `config.json` by default although this can be overridden by the `-c/--config` command line argument.

| Metric Name | Address    | Tags                                  |
|-------------| -----------|---------------------------------------|
| HS110-1     | 192.0.2.10 | test-tag-1 = true, test-tag-2 = false |
| HS110-2     | 192.0.2.11 | None                                  |

```json
{
    "HS110-1": {
        "address": "192.0.2.10",
        "tags": {
            "test-tag-1": true,
            "test-tag-2": false
        }
    },
    "HS110-2": {
        "address": "192.0.2.11"
    }
}
```

Will yield to STDOUT:

```bash
Test Plug 1,test-tag-1=true,test-tag-2=false voltage=240657i,current=288i,power=62120i
Test Plug 2 voltage=240657i,current=288i,power=62120i
```

### Telegraf Configuration

```bash
[[inputs.exec]]
  commands = [
    "/path/to/script/influx_hs110_energy.rb"
  ]
  timeout = "5s"
  data_format = "influx"
```
