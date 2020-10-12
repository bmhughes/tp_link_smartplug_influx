module TpLinkSmartplugInflux
  class Plug
    class CalculatedFieldCollection < TpLinkSmartplugInflux::Base
      def initialize
        @calc_field_collection = {}
      end

      def add(field)
        raise CalculatedFieldCollectionAddError, "Wrong class #{field.class}." unless field.is_a?(TpLinkSmartplugInflux::Plug::CalculatedField)

        @calc_field_collection[field.name] = field
      end

      def remove(field_name)
        @calc_field_collection.delete(field_name)
      end

      def count
        @calc_field_collection.count
      end

      def empty?
        @calc_field_collection.empty?
      end

      def list
        @calc_field_collection.keys
      end

      def to_h
        @calc_field_collection
      end

      def evaluate_all(data)
        return if @calc_field_collection.empty?

        calc_field_result = []

        @calc_field_collection.each do |_, calc_field|
          calc_field_result.push(calc_field.evaluate(data).map { |k, v| "#{k}=#{iflf_formatted_value(v)}" }.join(','))
        end

        calc_field_result.join(',')
      end
    end

    class CalculatedFieldCollectionError < TpLinkSmartplugInflux::BaseError; end
    class CalculatedFieldCollectionAddError < CalculatedFieldCollectionError; end
  end
end
