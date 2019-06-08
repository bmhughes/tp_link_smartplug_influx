# tp_link_smartplug_influx_influx

Ruby script to retrieve energy data from a TP Link HS110 smart plug and out it in InfluxDB Line Protocol to be called by the telegraf *exec* input plugin.

![Release](https://img.shields.io/github/release/bmhughes/tp_link_smartplug_influx.svg) ![License](https://img.shields.io/github/license/bmhughes/tp_link_smartplug_influx.svg)

## Change Log

- See [CHANGELOG.md](/CHANGELOG.md) for version details and changes.

### Usage

```bash
bundle install
./influx_hs110_energy.rb
```

#### Script

Metric name: Test Plug 1
Address: 192.0.2.10
Tags: Test-Tag-1, Test-Tag-2

```ruby

plugs = {
  'Test Plug 1' => {
    'address' => '192.0.2.10',
    'tags' => {
      'test-tag-1' => 'true',
      'test-tag-2' => 'false'
    }
  },
  'Test Plug 2' => {
    'address' => '192.0.2.11',
    'tags' => {
      'test-tag-1' => 'false',
      'test-tag-2' => 'true'
    }
  }
}

```

Will yield to STDOUT:

```bash
Test Plug 1,test-tag-1=true,test-tag-2=false voltage=240657i,current=288i,power=62120i
Test Plug 2,test-tag-1=false,test-tag-2=true voltage=240657i,current=288i,power=62120i
```

#### Telegraf

```bash
[[inputs.exec]]
  commands = [
    "/path/to/script/influx_hs110_energy.rb"
  ]
  timeout = "5s"
  data_format = "influx"
```
