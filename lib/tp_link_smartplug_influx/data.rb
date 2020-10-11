module TpLinkSmartplugInflux
  module Data
    DEFAULT_TAGS = {
      'alias' => :dev_alias
    }.freeze

    ENERGY_FIELDS = {
      'voltage_mv' => :voltage,
      'current_ma' => :current,
      'power_mw' => :power
    }.freeze

    INFO_FIELDS = {
      'relay_state' => :relay_state,
      'on_time' => :on_time,
      'rssi' => :rssi
    }.freeze
  end
end
