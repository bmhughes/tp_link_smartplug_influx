#!/usr/bin/env ruby
# frozen_string_literal: false

require 'tp_link_smartplug'
require 'time'

plugs = {
  'HS110-1' => {
    'address' => '192.0.2.10',
    'tags' => {
      'test-tag-1' => 'true',
      'test-tag-2' => 'false'
    }
  }
}

plugs.each do |name, config|
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
    measurement_string.concat("#{field}=#{data['emeter']['get_realtime'][field_value]}i,")
  end

  puts(measurement_string)
end
