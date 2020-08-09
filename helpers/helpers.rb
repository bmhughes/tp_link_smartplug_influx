# frozen_string_literal: false

def debug_message(string)
  caller_method = caller_locations(1..1).first.label
  STDOUT.puts(Time.now.strftime('%Y-%m-%d %H:%M:%S: ').concat("#{caller_method}: ").concat(string))
end

def nil_or_empty?(object)
  object.nil? || object.empty?
end

def seconds_since(time)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - time).round(2)
end
