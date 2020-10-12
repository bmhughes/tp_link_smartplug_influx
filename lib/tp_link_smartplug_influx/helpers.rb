def nil_or_empty?(value)
  return true if value.nil? || (value.respond_to?(:empty?) && value.empty?)

  false
end

def debug_message(string)
  caller_method = caller_locations(1..1).first.label
  STDOUT.puts(Time.now.strftime('%Y-%m-%d %H:%M:%S: ').concat("#{caller_method}: ").concat(string))
end

def seconds_since(time)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - time).round(2)
end

module TpLinkSmartplugInflux
  module Helpers
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
