module TpLinkSmartplugInflux
  class Plug
    # Class for generation of user-defined calculated data field.
    # @attr name [String]
    # @attr default [String, Integer]
    # @attr field [String]
    class CalculatedField < TpLinkSmartplugInflux::Base
      attr_reader :name
      attr_reader :default
      attr_reader :field

      attr_accessor :conditions

      CALCULATED_FIELD_ALLOWED_OPERATORS ||= %i(= > < >= <=).freeze
      CALCULATED_FIELD_ALLOWED_TYPES ||= %w(Integer integer Float float String string).freeze

      # Create a new instance of a calculated field.
      # @param name [String] Calculated field name.
      # @param default [Integer, String] Default value to use when an ambigious result is found.
      # @param field [String] Data field name to evalulate against.
      # @param conditions [Hash] Condition configuration Hash.
      def initialize(name:, default:, field:, type: 'Integer', conditions: {})
        raise CalculatedFieldError if nil_or_empty?(name)
        raise CalculatedFieldError, "Invalid type #{type} for calculated field #{name}" unless CALCULATED_FIELD_ALLOWED_TYPES.include?(type)

        @name = name
        @default = default
        @field = field
        @field_type = type

        raise unless conditions.is_a?(Hash)

        @conditions = conditions
      end

      # Evaulate the field conditions against the provided data hash.
      # @param data [Hash] Data hash to evaluate against.
      # @return [Hash] Result hash.
      def evaluate(data)
        raise CalculatedFieldError, "Calculated field #{@name} has no conditions." if @conditions.empty?

        result = {}
        @conditions.each do |value, conditions|
          raise CalculatedFieldError, "Calculated field #{@name}, condition value #{value} has no conditions." if @conditions.empty?

          typed_value = case @field_type
                        when 'Integer', 'integer'
                          value.to_i
                        when 'Float', 'float'
                          value.to_f
                        else
                          value
                        end

          result[typed_value] ||= []
          conditions.each do |opp, val|
            raise CalculatedFieldError, "Invalid operator #{opp} specified, operator must be one of: #{CALCULATED_FIELD_ALLOWED_OPERATORS.join(',')}" unless CALCULATED_FIELD_ALLOWED_OPERATORS.include?(opp.to_sym)

            result[typed_value].push(data[@field.to_sym].send(opp, val))
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

      # Return number of conditions configured for field
      # @return [Integer] Condition count.
      def condition_count
        @conditions.count
      end

      # Return calculated field in configuration hash format
      # @return [Hash] Calculated field as per configuration hash.
      def to_h
        {
          @name => {
            'default' => @default,
            'field' => @field,
            'conditions' => @conditions
          }
        }
      end

      # Error class representing an error when evaluating the calculated field.
      class CalculatedFieldError < TpLinkSmartplugInflux::BaseError; end
    end
  end
end
