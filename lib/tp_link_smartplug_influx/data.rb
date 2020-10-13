module TpLinkSmartplugInflux
  # Module containing constants used for retrieving data from the plug.
  #
  # @author Ben Hughes
  module Data
    # Default tags to return
    DEFAULT_TAGS = {
      'alias' => :dev_alias
    }.freeze

    # Default energy fields to return
    ENERGY_FIELDS = {
      'voltage_mv' => :voltage,
      'current_ma' => :current,
      'power_mw' => :power
    }.freeze

    # Default info fields to return
    INFO_FIELDS = {
      'relay_state' => :relay_state,
      'on_time' => :on_time,
      'rssi' => :rssi
    }.freeze
  end
end
