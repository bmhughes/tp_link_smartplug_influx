#!/usr/bin/env ruby
# frozen_string_literal: false

## Version 0.1.0

require 'tp_link_smartplug'
require 'time'
require 'json'
require 'optparse'

def debug_message(string)
  caller_method = caller_locations(1..1).first.label
  STDOUT.puts(Time.now.strftime('%Y-%m-%d %H:%M:%S: ').concat("#{caller_method}: ").concat(string))
end

options = {
  config: './config.json',
  verbose: false
}
OptionParser.new do |opts|
  opts.banner = "Usage: influx_hs110_energy.rb [options]"

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end

  opts.on('-v', '--verbose', 'Enable verbose output, breaks influx line format. TESTING ONLY') do |v|
    options[:verbose] = v
  end

  opts.on('-c FILE', '--config FILE', 'Configuration file location') do |c| 
    options[:config] = c
  end
end.parse!

if File.exist?(File.absolute_path(options[:config]))
  plugs = JSON.load(File.read(options[:config]))
else
  raise ArgumentError, "Config file #{File.absolute_path(options[:config])} does not exist!"
end

debug_message("There are #{plugs.count} plugs to process.") if options[:verbose]

plugs.each do |name, config|
  debug_message("Processing plug #{name}.") if options[:verbose]
  data = TpLinkSmartplug::Device.new(address: config['address']).energy

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
end
