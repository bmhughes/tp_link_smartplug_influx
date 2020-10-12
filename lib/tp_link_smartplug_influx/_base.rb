require_relative 'helpers'

module TpLinkSmartplugInflux
  class Base
    include TpLinkSmartplugInflux::Helpers
  end

  class BaseError < StandardError; end
end
