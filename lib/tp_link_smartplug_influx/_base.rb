require_relative 'helpers'

module TpLinkSmartplugInflux
  # Base plug class.
  #
  # @author Ben Hughes
  class Base
    include TpLinkSmartplugInflux::Helpers

    def initialize; end
  end

  # Base plug error class.
  #
  # @author Ben Hughes
  class BaseError < StandardError; end
end
