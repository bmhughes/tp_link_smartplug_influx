require 'resolv'
require 'tp_link_smartplug'

module TpLinkSmartplugInflux
  # Plug class for use with Influx line-format.
  # @attr name [String]
  # @attr timeout [Integer]
  # @attr calculated_fields [TpLinkSmartplugInflux::Plug::CalculatedFieldCollection]
  # @attr verbose [TrueClass, FalseClass]
  # @attr debug [TrueClass, FalseClass]
  # @attr address [String]
  class Plug < TpLinkSmartplugInflux::Base
    attr_accessor :name
    attr_accessor :timeout
    attr_accessor :calculated_fields
    attr_accessor :verbose

    # @overload debug
    #   @return [TrueClass, FalseClass] Return the present debug state.
    # @overload debug=(value)
    #   @param value [TrueClass, FalseClass] Set the debug state.
    attr_reader :debug

    def debug=(dbg)
      @debug = dbg
      @device.debug = dbg
      @verbose = dbg if dbg
    end

    attr_reader :address

    # Plug default data fields
    DATA_FIELDS = %i(info energy).freeze

    # Create a new instance of the plug class.
    # @param name [String] Name of the plug, will be used for the influx metric name tag.
    # @param address [String] FQDN/IP address of plug.
    # @param timeout [Integer] Plug polling timeout.
    # @return [nil]
    def initialize(name:, address:, timeout: 3)
      @name = name

      @device = TpLinkSmartplug::Device.new(address: Resolv.getaddress(address))
      @device.timeout = timeout

      @device_last_polled = nil

      @verbose = false
      @debug = false

      @calculated_fields = TpLinkSmartplugInflux::Plug::CalculatedFieldCollection.new

      debug_message("Initialised new plug #{@name} with timeout #{device.timeout}.") if @debug
    end

    # get all data for the plug.
    # @return [Hash]
    def data
      data = {}
      DATA_FIELDS.each { |field| data.merge!(public_send(field)) }

      debug_message("Returned #{data.count} data items for plug #{@name}.") if @verbose
      debug_message("Plug #{@name} returned data: #{data}") if @debug

      data
    end

    # Get the system data for the plug.
    # @return [String]
    def info
      poll_plug

      plug_info = @sysinfo.dup

      raise PlugDataError, "Plug information empty for plug #{@name}." if plug_info.empty?

      plug_info.delete_if { |k, _| !TpLinkSmartplugInflux::Data::INFO_FIELDS.key?(k) }
      plug_info.transform_keys(&TpLinkSmartplugInflux::Data::INFO_FIELDS.method(:[]))
    end

    # Get the energy data for the plug.
    # @return [String]
    def energy
      poll_plug

      plug_energy = @energy.dup

      raise PlugDataError, "Energy data empty for plug #{@name}." if plug_energy.empty?

      plug_energy.delete_if { |k, _| !TpLinkSmartplugInflux::Data::ENERGY_FIELDS.key?(k) }
      plug_energy.transform_keys(&TpLinkSmartplugInflux::Data::ENERGY_FIELDS.method(:[]))
    end

    # Get the tags for the plug.
    # @return [String]
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

    # Output a string in influx line format for the plug.
    # @return [String]
    def influx_line
      iflf_string = ''
      iflf_string.concat("#{tags} ")

      values = []
      DATA_FIELDS.each { |type| values.concat(public_send(type).map { |k, v| "#{k}=#{iflf_formatted_value(v)}" }) }

      unless calculated_fields.empty?
        values.push(calculated_fields.evaluate_all(energy))
      end

      iflf_string.concat(values.join(','))

      iflf_string
    end

    private

    # Poll the plug for fresh data.
    # @return [TrueClass, FalseClass] Returns true if the plug was polled and false if cached result was used.
    def poll_plug
      if @device_last_polled.nil? || (seconds_since(@device_last_polled) > 3)
        debug_message("Polling plug #{@name}.") if @verbose

        @sysinfo = @device.info['system']['get_sysinfo'].sort.to_h
        @energy =  @device.energy['emeter']['get_realtime'].sort.to_h

        @device_last_polled = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        true
      elsif @debug
        debug_message("NOT polling plug #{@name} as time since last polled is < 3 seconds. Time since last polled: #{seconds_since(@device_last_polled)}s.")

        false
      end
    rescue RuntimeError => e
      raise PlugPollError, "Error occured polling plug #{@name}, inner error: \n #{e}"
    end

    # Error class representing an error with the data returned from the plug.
    class PlugDataError < TpLinkSmartplugInflux::BaseError; end

    # Error class representing an error when polling the plug for data.
    class PlugPollError < TpLinkSmartplugInflux::BaseError; end
  end
end

require_relative 'plug/calculated_field'
require_relative 'plug/calculated_field_collection'
