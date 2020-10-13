# tp_link_smartplug_influx

Ruby script to retrieve energy and system data from a TP Link HS110 smart plug and output it in InfluxDB Line Protocol.
Intended to be called by the telegraf *exec* input plugin.

![Release](https://img.shields.io/github/release/bmhughes/tp_link_smartplug_influx.svg)
![License](https://img.shields.io/github/license/bmhughes/tp_link_smartplug_influx.svg)
[![Build Status](https://travis-ci.org/bmhughes/tp_link_smartplug_influx.svg?branch=master)](https://travis-ci.org/bmhughes/tp_link_smartplug_influx)

- [Usage](#usage)
- [Tags](#tags)
- [Fields](#fields)
- [Calculated Fields](#calculated-fields)
- [Configuration File Format](#configuration-file)
- [Telegraf Configuration](#telegraf-configuration)

## Change Log

- See [CHANGELOG.md](/CHANGELOG.md) for version details and changes.

## Usage

```bash
bundle install
./influx_hs110_energy.rb
```

```bash
Usage: influx_hs110_energy.rb [options]
    -h, --help                       Prints this help
    -v, --verbose                    Enable verbose output, breaks influx line format. TESTING ONLY
    -d, --debug                      Enable debug output, breaks influx line format. TESTING ONLY
    -s, --stop-on-error              Enable script execution stop on error when polling a plug
    -m, --measurement-name NAME      Name for the Influx measurement
    -a, --address ADDRESS            IP or FDQN of plug to poll
    -c, --config FILE                Configuration file
```

You can either specify a single host on the command line (via option `-a`) or provide multiple hosts in a configuration file in JSON format.

## Tags

By default the following tags are added to the measurement:

- Plug name from configuratoin
- Plug description from Kasa/Plug

## Fields

By default the following fields are added to the measurement:

- Voltage (mV)
- Current (mA)
- Power (mW)
- Relay State (0/1)
- Power On Time (seconds)
- WLAN RSSI (dBm)

## Calculated Fields

The script has supported for creating calculated fields by comparison with another field, this is a crutch to provide derived fields until Influx 2 adds conditional query support.

### Example

With the below configuration the `state` field will be `0` when the `power` field is between 30000mW and 100000mW and `1` when greater than `100000`.

```json
"calculated_fields": {
                "state": {
                    "default": -1,
                    "field": "power",
                    "conditions": {
                        "0": {
                            ">=": 30000,
                            "<=" : 100000
                        },
                        "1": {
                            ">": 100000
                        }
                    }
                }
            }
```

## Configuration File

Configuration is performed via JSON file which is `config.json` by default although this can be overridden by the `-c/--config` command line argument.

### Format

```json
{
    "Measurement": {
        "Plug": {
            "address": "IP address/FQDN of plug",
            "calculated_fields": {
                "field_name": {
                    "default": "Default value",
                    "field": "Field to examine",
                    "conditions": {
                        "value": {
                            "operator": "Comparison value"
                        }
                    }
                }
            },
            "fields": {
                "energy": {
                    "Influx field name": "Field from plug energy data"
                },
                "info": {
                    "Influx field name": "Field from plug info data"
                }
            },
            "tags": {
                "Tag name": "Tag value"
            }
        }
    }
}
```

### Example

| Measurement Name | Metric Name | Address    | Tags                                  | Calculated Fields                                                    |
|------------------|-------------| -----------|---------------------------------------|----------------------------------------------------------------------|
| Measurement-01   | Plug-01     | 192.0.2.10 | test-tag-1 = true, test-tag-2 = false | None                                                                 |
|                  | Plug-02     | 192.0.2.11 | None                                  | None                                                                 |
| Measurement-02   | Plug-01     | 192.0.2.20 | None                                  | None                                                                 |
| Measurement-03   | Plug-01     | 192.0.2.30 | None                                  | state: "0": { ">=": 30000 and "<=" : 100000 }, "1": { ">": 100000 }  |

```json
{
    "Measurement-01": {
        "Plug-01": {
            "address": "192.0.2.10"
        },
        "Plug-02": {
            "address": "192.0.2.11"
        }
    },
    "Measurement-02": {
        "Plug-01": {
            "address": "192.0.2.20"
        },
    },
    "Measurement-03": {
        "Plug-01": {
            "address": "192.0.2.30",
            "calculated_fields": {
                "default": -1,
                "field": "power",
                "conditions": {
                    "0": {
                        ">=": 30000,
                        "<=" : 100000
                    },
                    "1": {
                        ">=": 100000
                    }
                }
            }
        }
    }
}
```

Testing,plug=GBMDS-SPL-HS110-01,dev_alias=Garage\ Air\ Conditioning voltage=242107i,current=285i,power=61984i,relay_state=1i,on_time=1869899i,rssi=-37i,state=0i
Testing,plug=GBMDS-SPL-HS110-02,dev_alias=Garage\ UPS\ 1 voltage=243168i,current=1942i,power=439368i,relay_state=1i,on_time=157603i,rssi=-38i
Testing,plug=GBMDS-SPL-HS110-03,dev_alias=Garage\ UPS\ 2 voltage=242570i,current=1055i,power=153496i,relay_state=1i,on_time=54949i,rssi=-40i
Testing,plug=GBMDS-SPL-HS110-04,dev_alias=Garage\ UPS\ 3 voltage=242248i,current=1656i,power=370625i,relay_state=1i,on_time=54881i,rssi=-39i
Testing,plug=GBMDS-SPL-HS110-05,dev_alias=Garage\ UPS\ 4 voltage=245340i,current=1353i,power=292023i,relay_state=1i,on_time=54877i,rssi=-39i

Will yield to STDOUT:

```bash
Measurement-01,plug=Plug-01,test-tag-1=true,test-tag-2=false voltage=240657i,current=288i,power=62120i
Measurement-01,plug=Plug-02 voltage=240657i,current=288i,power=62120i
Measurement-02,plug=Plug-01 voltage=240657i,current=288i,power=62120i
Measurement-03,plug=Plug-01 voltage=240657i,current=288i,power=62120i,state=0i
```

## Telegraf Configuration

```bash
[[inputs.exec]]
  commands = [
    "/path/to/script/influx_hs110_energy.rb"
  ]
  timeout = "5s"
  data_format = "influx"
```
