# Test an attribute for nil or empty-ness
# @param value The value to test.
# @return [TrueClass, FalseClass] The test result.
def nil_or_empty?(value)
  return true if value.nil? || (value.respond_to?(:empty?) && value.empty?)

  false
end

# Generate a debug message to STDOUT
# @param string [String] Debug string to format and output.
def debug_message(string)
  caller_method = caller_locations(1..1).first.label
  STDOUT.puts(Time.now.strftime('%Y-%m-%d %H:%M:%S: ').concat("#{caller_method}: ").concat(string))
end

# Get the number of seconds elapsed since the provided time.
# @param time [Float] Previous time input.
# @return [Integer] Seconds elapsed.
def seconds_since(time)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - time).round(2)
end

module TpLinkSmartplugInflux
  # Module containing helper methods to be included within the base class.
  #
  # @author Ben Hughes
  module Helpers
    # Correctly formats a data value for ingestion by Influx.
    # @param value [Integer, Float, String] The value to format
    # @return [String] A correctly influx-formatted value.
    def iflf_formatted_value(value)
      case value
      when Integer
        "#{value}i"
      when String
        "\"#{value}\""
      else
        value.to_s
      end
    end
  end
end
