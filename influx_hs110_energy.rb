#!/usr/bin/env ruby
# frozen_string_literal: false

## Version 0.3.0

require 'tp_link_smartplug'
require 'time'
require 'json'
require 'optparse'
require 'ipaddr'
require 'resolv'

def debug_message(string)
  caller_method = caller_locations(1..1).first.label
  STDOUT.puts(Time.now.strftime('%Y-%m-%d %H:%M:%S: ').concat("#{caller_method}: ").concat(string))
end

options = {
  verbose: false,
  silent_error: true,
}

OptionParser.new do |opts|
  opts.banner = 'Usage: influx_hs110_energy.rb [options]'

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end

  opts.on('-v', '--verbose', 'Enable verbose output, breaks influx line format. TESTING ONLY') do |v|
    options[:verbose] = v
  end

  opts.on('-s', '--stop-on-error', 'Enable script execution stop on error when polling a plug') do
    options[:silent_error] = false
  end

  opts.on('m', '--measurement-name', 'Name for the Influx measurement') do |m|
    options[:measurement] = m
  end

  opts.on('-a ADDRESS', '--address ADDRESS', 'IP or FDQN of plug to poll') do |h|
    begin
      options[:hostname] = h
      options[:address] = IPAddr.new(Resolv.getaddress(h))
    rescue Resolv::ResolvError
      puts "Unable to resolve address for host #{h}"
      exit
    end
  end

  opts.on('-c FILE', '--config FILE', 'Configuration file') do |c|
    options[:config] = c
  end
end.parse!

if options.key?(:address) && !options.key?(:config)
  measurements = {}
  measurements[options[:hostname]] = {}
  measurements[options[:hostname]][options[:hostname]] = {}
  measurements[options[:hostname]][options[:hostname]]['address'] = options[:address].to_s
else
  options[:config] ||= __dir__.concat('/config.json')
  options[:config] = File.absolute_path(options[:config])
  measurements = JSON.parse(File.read(options[:config])) if File.exist?(options[:config])
  raise ArgumentError, "Config file #{options[:config]} does not exist!" unless File.exist?(options[:config])
end

debug_message("There are #{measurements.count} measurements to process.") if options[:verbose]

unless measurements.empty?
  measurements.each do |measurement, plugs|
    if plugs.nil? || plugs.empty?
      debug_message("No plugs configured for measurement name #{measurement}!")
      next
    end

    debug_message("There are #{plugs.count} plugs to process for measurement #{measurement}.") if options[:verbose]

    plugs.each do |plug, config|
      debug_message("Processing plug #{plug}.") if options[:verbose]
      begin
        device = TpLinkSmartplug::Device.new(address: Resolv.getaddress(config['address']))
        device.timeout = 1

        # Poll plug for data
        info_data = device.info
        energy_data = device.energy

        measurement_string = ''
        measurement_string.concat(measurement)

        # Add plug name tag
        measurement_string.concat(",plug=#{plug.gsub(/( |,|=)/, '\\\\\1')}")
        # Default tags from info_data
        {
          'dev_alias': 'alias',
        }.each do |tag, tag_value|
          debug_message("Processing field #{tag}.") if options[:verbose]
          escaped_tag_value = info_data['system']['get_sysinfo'][tag_value].gsub(/( |,|=)/, '\\\\\1')
          measurement_string.concat(",#{tag}=#{escaped_tag_value}")
        end

        # Custom tags
        config['tags'].each { |tag, value| measurement_string.concat("#{tag}=#{value},") } unless config['tags'].nil? || config['tags'].empty?

        measurement_string.concat(' ')

        # Energy meter fields
        {
          'voltage': 'voltage_mv',
          'current': 'current_ma',
          'power': 'power_mw',
        }.each do |field, field_value|
          debug_message("Processing field #{field}.") if options[:verbose]
          measurement_string.concat("#{field}=#{energy_data['emeter']['get_realtime'][field_value]}i,")
        end

        # System info fields
        {
          'relay_state': 'relay_state',
          'on_time': 'on_time',
          'rssi': 'rssi',
        }.each do |field, field_value|
          debug_message("Processing field #{field}.") if options[:verbose]
          measurement_string.concat("#{field}=#{info_data['system']['get_sysinfo'][field_value]}i,")
        end

        measurement_string = measurement_string[0...-1]
        puts(measurement_string)
      rescue RuntimeError
        unless options[:silent_error]
          puts "Error occured polling plug #{name}"
          exit 1
        end
      end
    end
  end
end
