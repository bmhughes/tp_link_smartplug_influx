require 'resolv'
require 'tp_link_smartplug'

module TpLinkSmartplugInflux
  class Plug < TpLinkSmartplugInflux::Base
    attr_accessor :name
    attr_accessor :timeout
    attr_accessor :calculated_fields
    attr_accessor :verbose

    attr_reader :debug
    attr_reader :address

    DATA_FIELDS = %i(info energy).freeze

    def initialize(name:, address:, timeout: 1)
      @name = name

      @device = TpLinkSmartplug::Device.new(address: Resolv.getaddress(address))
      @device.timeout = timeout

      @device_last_polled = nil

      @verbose = false
      @debug = false

      @calculated_fields = TpLinkSmartplugInflux::Plug::CalculatedFieldCollection.new

      debug_message("Initialised new plug #{@name} with timeout #{device.timeout}.") if @debug
    end

    def debug=(dbg)
      @debug = dbg
      @device.debug = dbg
      @verbose = dbg if dbg
    end

    def data
      data = {}
      DATA_FIELDS.each { |field| data.merge!(public_send(field)) }

      debug_message("Returned #{data.count} data items for plug #{@name}.") if @verbose
      debug_message("Plug #{@name} returned data: #{data}") if @debug

      data
    end

    def info
      poll_plug

      plug_info = @sysinfo.dup

      raise PlugDataError, "Plug information empty for plug #{@name}." if plug_info.empty?

      plug_info.delete_if { |k, _| !TpLinkSmartplugInflux::Data::INFO_FIELDS.key?(k) }
      plug_info.transform_keys(&TpLinkSmartplugInflux::Data::INFO_FIELDS.method(:[]))
    end

    def energy
      poll_plug

      plug_energy = @energy.dup

      raise PlugDataError, "Energy data empty for plug #{@name}." if plug_energy.empty?

      plug_energy.delete_if { |k, _| !TpLinkSmartplugInflux::Data::ENERGY_FIELDS.key?(k) }
      plug_energy.transform_keys(&TpLinkSmartplugInflux::Data::ENERGY_FIELDS.method(:[]))
    end

    def tags
      poll_plug unless @sysinfo

      raise PlugDataError, "System information empty for plug #{@name}." if @sysinfo.empty?

      tags = []
      tags.push("plug=#{@name.gsub(/( |,|=)/, '\\\\\1')}")

      TpLinkSmartplugInflux::Data::DEFAULT_TAGS.each do |tag_value, tag|
        escaped_tag_value = @sysinfo[tag_value].gsub(/( |,|=)/, '\\\\\1')
        tags.push("#{tag}=#{escaped_tag_value}")
      end

      tags.join(',')
    end

    def influx_line
      iflf_string = ''

      iflf_string.concat(tags)
      iflf_string.concat(' ')

      values = []
      DATA_FIELDS.each { |type| values.push(public_send(type).map { |k, v| "#{k}=#{iflf_formatted_value(v)}" }.join(',')) }

      unless calculated_fields.empty?
        values.push(calculated_fields.evaluate_all(energy))
      end

      iflf_string.concat(values.join(','))

      iflf_string
    end

    private

    def poll_plug
      if @device_last_polled.nil? || (seconds_since(@device_last_polled) > 3)
        debug_message("Polling plug #{@name}.") if @verbose

        @sysinfo = @device.info['system']['get_sysinfo'].sort.to_h
        @energy =  @device.energy['emeter']['get_realtime'].sort.to_h

        @device_last_polled = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elsif @debug
        debug_message("NOT polling plug #{@name} as time since last polled is < 3 seconds. Time since last polled: #{seconds_since(@device_last_polled)}s.")
      end
    rescue RuntimeError => e
      raise PlugPollError, "Error occured polling plug #{@name}, inner error: \n #{e}"
    end
  end

  class PlugDataError < TpLinkSmartplugInflux::BaseError; end
  class PlugPollError < TpLinkSmartplugInflux::BaseError; end
end

require_relative 'plug/calculated_field'
require_relative 'plug/calculated_field_collection'
