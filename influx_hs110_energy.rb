#!/usr/bin/env ruby

require 'ipaddr'
require 'json'
require 'optparse'
require 'resolv'
require 'tp_link_smartplug'

require_relative 'lib/tp_link_smartplug_influx'

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
    options[:hostname] = h
    options[:address] = IPAddr.new(Resolv.getaddress(h))
  rescue Resolv::ResolvError
    puts "Unable to resolve address for host #{h}"
    exit
  end

  opts.on('-c FILE', '--config FILE', 'Configuration file') do |c|
    options[:config] = c
  end
end.parse!

total_time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

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

unless nil_or_empty?(measurements)
  measurement_strings = []
  measurements.each do |measurement, plugs|
    if nil_or_empty?(plugs)
      debug_message("No plugs configured for measurement name #{measurement}!")
      next
    end

    debug_message("There are #{plugs.count} plugs to process for measurement #{measurement}.") if options[:verbose]

    threads = []

    plugs.each do |plug_name, config|
      unless config.fetch('enabled', true)
        debug_message("Processing disabled for plug #{plug_name}.") if options[:verbose]
        next
      end

      puts if options[:verbose]
      debug_message("Processing plug #{plug_name}.") if options[:verbose]
      threads << Thread.new do
        debug_message("Creating processing thread for plug #{plug_name}.") if options[:verbose]
        begin
          time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          plug = TpLinkSmartplugInflux::Plug.new(name: plug_name, address: config['address'])
          plug.timeout = 1
          %i(debug= verbose=).each { |opt| plug.send(opt, config[opt]) }

          unless nil_or_empty?(config['calculated_fields'])
            config['calculated_fields'].each do |field, field_config|
              debug_message("Adding calculated field '#{field}' for plug #{plug_name} data field '#{field_config['field']}' with #{field_config['conditions'].count} conditions.") if options[:debug]

              plug.calculated_fields.add(
                TpLinkSmartplugInflux::Plug::CalculatedField.new(
                  name: field,
                  default: field_config['default'],
                  field: field_config['field'],
                  type: field_config['type'],
                  conditions: field_config['conditions']
                )
              )
            end
          end

          measurement_string = ''
          measurement_string.concat("#{measurement},")
          measurement_string.concat(plug.influx_line)
          measurement_string.concat(",polltime=#{milliseconds_since(time_start)}")

          measurement_strings.push(measurement_string)

          debug_message("Took #{seconds_since(time_start)} seconds to poll plug #{plug_name}") if options[:debug]
        rescue TpLinkSmartplugInflux::BaseError => e
          debug_message("Error occured processing plug #{plug_name}:\n #{e}") if options[:verbose]
          exit 1 unless options[:silent_error]
        end
      end
    end

    threads.each(&:join)
  end
end

unless measurement_strings.empty?
  puts "\nInflux line protocol data:\n" if options[:verbose]
  measurement_strings.sort.each do |measurement|
    puts measurement
  end
  puts "TPLink-Smartplug-Influx-rb polltime_total=#{milliseconds_since(total_time_start)}"
end

if options[:debug]
  puts
  debug_message("Took #{seconds_since(total_time_start)} seconds to poll all plugs.")
end
