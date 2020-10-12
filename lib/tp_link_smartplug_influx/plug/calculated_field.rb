module TpLinkSmartplugInflux
  class Plug
    class CalculatedField < TpLinkSmartplugInflux::Base
      attr_reader :name
      attr_reader :default
      attr_reader :field

      attr_accessor :conditions

      CALCULATED_FIELD_ALLOWED_OPERATORS ||= %i(= > < >= <=).freeze

      def initialize(name:, default:, field:, conditions: {})
        raise CalculatedFieldError if nil_or_empty?(name)

        @name = name
        @default = default
        @field = field

        raise unless conditions.is_a?(Hash)

        @conditions = conditions
      end

      def evaluate(data)
        raise CalculatedFieldError, "Calculated field #{@name} has no conditions." if @conditions.empty?

        result = {}
        @conditions.each do |value, conditions|
          raise CalculatedFieldError, "Calculated field #{@name}, condition value #{value} has no conditions." if @conditions.empty?

          result[value] ||= []
          conditions.each do |opp, val|
            raise CalculatedFieldError, "Invalid operator #{opp} specified, operator must be one of: #{CALCULATED_FIELD_ALLOWED_OPERATORS.join(',')}" unless CALCULATED_FIELD_ALLOWED_OPERATORS.include?(opp.to_sym)

            result[value].push(data[@field.to_sym].send(opp, val))
          end
        end
        result = result.select { |_, res| res.all? { |r| r.eql?(true) } }

        if result.count > 1
          debug_message("Calculated field #{calc_field_name} returned ambigious result!")
          { @name => @default }
        else
          { @name => result.keys.first }
        end
      end

      def condition_count
        @conditions.count
      end

      def to_h
        {
          @name => {
            'default' => @default,
            'field' => @field,
            'conditions' => @conditions
          }
        }
      end
    end

    class CalculatedFieldError < TpLinkSmartplugInflux::BaseError; end
  end
end
