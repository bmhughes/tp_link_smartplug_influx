require 'resolv'
require 'tp_link_smartplug'

module TpLinkSmartplugInflux
  class Plug < TpLinkSmartplugInflux::Base
    attr_accessor :name
    attr_accessor :timeout
    attr_accessor :verbose
    attr_accessor :debug
    attr_accessor :silent_error

    attr_accessor :calculated_fields

    attr_reader :address

    DATA_FIELDS = %i(info energy).freeze

    def initialize(name:, address:, timeout: 1)
      @name = name

      @device = TpLinkSmartplug::Device.new(address: Resolv.getaddress(address))
      @device.timeout = timeout

      @verbose = false
      @debug = false
      @silent_error = true

      @calculated_fields = TpLinkSmartplugInflux::Plug::CalculatedFieldCollection.new
    end

    def data
      poll_plug

      data = {}
      DATA_FIELDS.each { |field| data.merge!(public_send(field)) }
      data
    end

    def info
      poll_plug

      plug_info = @sysinfo.dup
      plug_info.delete_if { |k, _| !TpLinkSmartplugInflux::Data::INFO_FIELDS.key?(k) }
      plug_info.transform_keys(&TpLinkSmartplugInflux::Data::INFO_FIELDS.method(:[]))
    end

    def energy
      poll_plug

      plug_energy = @energy.dup
      plug_energy.delete_if { |k, _| !TpLinkSmartplugInflux::Data::ENERGY_FIELDS.key?(k) }
      plug_energy.transform_keys(&TpLinkSmartplugInflux::Data::ENERGY_FIELDS.method(:[]))
    end

    def tags
      poll_plug unless @sysinfo

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
      @sysinfo = @device.info['system']['get_sysinfo']
      @energy =  @device.energy['emeter']['get_realtime']
    rescue RuntimeError
      raise "Error occured polling plug #{@name}" unless @silent_error
    end
  end
end

require_relative 'plug/calculated_field'
require_relative 'plug/calculated_field_collection'
