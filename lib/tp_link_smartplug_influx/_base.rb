require_relative 'helpers'

module TpLinkSmartplugInflux
  # Base plug class.
  #
  # @author Ben Hughes
  class Base
    include TpLinkSmartplugInflux::Helpers
  end

  # Base plug error class.
  #
  # @author Ben Hughes
  class BaseError < StandardError; end
end
