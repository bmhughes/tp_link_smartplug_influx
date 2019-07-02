#!/usr/bin/env ruby
# frozen_string_literal: false

## Version 0.2.0

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
  silent_error: true
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
  plugs = {}
  plugs[options[:hostname]] = {}
  plugs[options[:hostname]]['address'] = options[:address].to_s
else
  options[:config] ||= __dir__.concat('/config.json')
  options[:config] = File.absolute_path(options[:config])
  plugs = JSON.parse(File.read(options[:config])) if File.exist?(options[:config])
  raise ArgumentError, "Config file #{options[:config]} does not exist!" unless File.exist?(options[:config])
end

debug_message("There are #{plugs.count} plugs to process.") if options[:verbose]

unless plugs.empty?
  plugs.each do |name, config|
    debug_message("Processing plug #{name}.") if options[:verbose]
    begin
      device = TpLinkSmartplug::Device.new(address: Resolv.getaddress(config['address']))
      device.timeout = 1
      data = device.energy

      measurement_string = ''
      measurement_string.concat(name)
      config['tags'].each { |tag, value| measurement_string.concat(",#{tag}=#{value}") } unless config['tags'].nil? || config['tags'].empty?
      measurement_string.concat(' ')

      {
        'voltage': 'voltage_mv',
        'current': 'current_ma',
        'power': 'power_mw'
      }.each do |field, field_value|
        debug_message("Processing field #{field}.") if options[:verbose]
        measurement_string.concat("#{field}=#{data['emeter']['get_realtime'][field_value]}i,")
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
