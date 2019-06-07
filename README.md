# tp_link_smartplug_influx_influx

Ruby gem to retrieve data and control a TP Link HS100/HS110 smart plug.

![Release](https://img.shields.io/github/release/bmhughes/tp_link_smartplug_influx.svg) ![License](https://img.shields.io/github/license/bmhughes/tp_link_smartplug_influx.svg)

## Change Log

- See [CHANGELOG.md](/CHANGELOG.md) for version details and changes.

## influx_hs110_energy.rb

Outputs smart plug data in the InfluxDB line data format. For use with the **telegraf** *exec* input plugin. Set the metric name, address and tags in the `plugs` hash.

### Usage

```bash
bundle install
./influx_hs110_energy.rb
```

### Example

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
  }
}

```

Will yield to STDOUT:

```bash
Test Plug 1,test-tag-1=true,test-tag-2=false voltage=240657i,current=288i,power=62120i