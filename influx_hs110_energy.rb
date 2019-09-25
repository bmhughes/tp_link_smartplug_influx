#!/usr/bin/env ruby
# frozen_string_literal: false

## Version 0.3.0

require 'tp_link_smartplug'
require 'time'
require 'json'
require 'optparse'
require 'ipaddr'
require 'resolv'
require 'benchmark'
require_relative 'helpers/helpers.rb'

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

  opts.on('-d', '--debug', 'Enable debug output, breaks influx line format. TESTING ONLY') do |d|
    options[:verbose] = true
    options[:debug] = d
  end

  opts.on('-s', '--stop-on-error', 'Enable script execution stop on error when polling a plug') do
    options[:silent_error] = false
  end

  opts.on('-m', '--measurement-name NAME', 'Name for the Influx measurement') do |m|
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

total_time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC) if options[:debug]

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

# Default tags and measurements
tags = {
  'dev_alias': 'alias'
}

energy_fields = {
  'voltage': 'voltage_mv',
  'current': 'current_ma',
  'power': 'power_mw'
}

info_fields = {
  'relay_state': 'relay_state',
  'on_time': 'on_time',
  'rssi': 'rssi'
}

debug_message("There are #{measurements.count} measurements to process.") if options[:verbose]

unless nil_or_empty?(measurements)
  measurement_strings = []
  measurements.each do |measurement, plugs|
    if nil_or_empty?(plugs)
      debug_message("No plugs configured for measurement name #{measurement}!")
      next
    end

    debug_message("There are #{plugs.count} plugs to process for measurement #{measurement}.") if options[:verbose]

    plugs.each do |plug, config|
      data = {}

      calculated_fields = {}
      puts if options[:verbose]
      debug_message("Processing plug #{plug}.") if options[:verbose]
      begin
        time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC) if options[:debug]
        device = TpLinkSmartplug::Device.new(address: Resolv.getaddress(config['address']))
        device.timeout = 1

        # Poll plug for data
        info_data = device.info['system']['get_sysinfo']
        energy_data = device.energy['emeter']['get_realtime']
        debug_message("Took #{seconds_since(time_start)} seconds to poll plug #{plug}") if options[:debug]

        measurement_string = ''
        measurement_string.concat(measurement)

        ## Tags
        # Add plug name tag
        measurement_string.concat(",plug=#{plug.gsub(/( |,|=)/, '\\\\\1')}")

        # Tags from info_data
        tags.merge!(config['tags']) if config['tags']
        tags.each do |tag, tag_value|
          debug_message("Processing tag #{tag}.") if options[:verbose]
          escaped_tag_value = info_data[tag_value].gsub(/( |,|=)/, '\\\\\1')
          measurement_string.concat(",#{tag}=#{escaped_tag_value}")
        end

        # Custom tags
        config['tags'].each { |tag, value| measurement_string.concat("#{tag}=#{value},") } unless config['tags'].nil? || config['tags'].empty?

        measurement_string.concat(' ')

        ## Fields
        # Energy meter fields
        energy_fields.merge!(config['fields']['energy']) if config['fields'] && config['fields']['energy']
        energy_fields.each do |field, field_value|
          debug_message("Processing field #{field}.") if options[:verbose]
          data[field] = energy_data[field_value].to_i
        end

        # System info fields
        info_fields.merge!(config['fields']['info']) if config['fields'] && config['fields']['info']
        info_fields.each do |field, field_value|
          debug_message("Processing field #{field}.") if options[:verbose]
          data[field] = info_data[field_value].to_i
        end

        # Calculated fields
        if nil_or_empty?(config['calculated_fields'])
          debug_message("There are no calculated fields to process for plug #{plug}.") if options[:verbose]
        else
          time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC) if options[:debug]
          debug_message("There are #{config['calculated_fields'].count} calculated fields to process for plug #{plug}.") if options[:verbose]
          config['calculated_fields'].each do |calc_field_name, calc_field_config|
            debug_message("Processing calculated field #{calc_field_name}") if options[:verbose]
            debug_message("Calculated field #{calc_field_name} config: #{calc_field_config}.") if options[:debug]

            if nil_or_empty?(calc_field_config['conditions'])
              debug_message("Calculated field #{calc_field_name} has no configuration!")
              next
            end

            result = {}
            calc_field_config['conditions'].each do |value, conditions|
              debug_message("Evaluating calculated field value #{value} against field #{calc_field_config['field']} with value #{data[calc_field_config['field'].to_sym]}.") if options[:debug]

              result[value] ||= []
              conditions.each do |opp, val|
                debug_message("Evaluating field condition #{opp} against value #{val}.") if options[:debug]
                result[value].push(data[calc_field_config['field'].to_sym].send(opp, val))
              end
            end
            result = result.select { |_, res| res.all? { |r| r.eql?(true) } }

            if result.count > 1
              debug_message("Calculated field #{calc_field_name} returned ambigious result!")
              calculated_fields[calc_field_name] = config['default']
            else
              calculated_fields[calc_field_name] = result.keys[0].to_i
            end

            debug_message("Calculated field #{calc_field_name} evaluated to result #{calculated_fields[calc_field_name]}.") if options[:verbose]
          end
          debug_message("Took #{seconds_since(time_start)} seconds to process #{config['calculated_fields'].count} calculated fields for plug #{plug}.") if options[:debug]
        end

        data.each do |field, value|
          measurement_string.concat("#{field}=#{value}i,")
        end

        calculated_fields.each do |field, value|
          measurement_string.concat("#{field}=#{value}i,")
        end

        measurement_string = measurement_string[0...-1]
        measurement_strings.push(measurement_string)
      rescue RuntimeError
        unless options[:silent_error]
          puts "Error occured polling plug #{name}"
          exit 1
        end
      end
    end
  end
end

unless measurement_strings.empty?
  puts "\nInflux line protocol data:\n" if options[:verbose]
  measurement_strings.each do |measurement|
    puts measurement
  end
end

debug_message("Took #{seconds_since(total_time_start)} seconds to poll all plugs.") if options[:debug]
