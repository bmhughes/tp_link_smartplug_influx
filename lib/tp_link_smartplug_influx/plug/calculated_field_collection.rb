module TpLinkSmartplugInflux
  class Plug
    # Collection of calculated fields for a plug.
    class CalculatedFieldCollection < TpLinkSmartplugInflux::Base
      # Create a new calculated field collection
      def initialize
        super()

        @calc_field_collection = {}
      end

      # Add a field to the collection.
      # @param field [TpLinkSmartplugInflux::Plug::CalculatedField]
      # @return [TrueClass]
      def add(field)
        raise CalculatedFieldCollectionAddError, "Wrong class #{field.class}." unless field.is_a?(TpLinkSmartplugInflux::Plug::CalculatedField)

        @calc_field_collection[field.name] = field
        true
      end

      # Remove a field from the collection.
      # @param field_name [String] Calculated field name to remove.
      # @return [TpLinkSmartplugInflux::Plug::CalculatedField] Removed field.
      def remove(field_name)
        @calc_field_collection.delete(field_name)
      end

      # Get the calculated field count in collection.
      # @return [Integer]
      def count
        @calc_field_collection.count
      end

      # Check if the collection is empty.
      # @return [TrueClass, FalseClass]
      def empty?
        @calc_field_collection.empty?
      end

      # List calculated field names in collection
      # @return [Array]
      def list
        @calc_field_collection.keys
      end

      # Return Hash of calculated field collection.
      # @return [Hash]
      def to_h
        @calc_field_collection
      end

      # Evalulate all fields in collection
      # @param data [Hash]
      # @return [String] Field results.
      def evaluate_all(data)
        return if @calc_field_collection.empty?

        calc_field_result = []

        @calc_field_collection.each do |_, calc_field|
          calc_field_result.push(calc_field.evaluate(data).map { |k, v| "#{k}=#{iflf_formatted_value(v)}" }.join(','))
        end

        calc_field_result.join(',')
      rescue CalculatedFieldError => e
        raise CalculatedFieldCollectionError, "Error occured evaluating calculated field #{calc_field.name}, inner error: \n #{e}"
      end

      # Error class representing an error when evaluating the calculated field collection.
      class CalculatedFieldCollectionError < TpLinkSmartplugInflux::BaseError; end

      # Error class representing an error when adding a calculated field to a collection.
      class CalculatedFieldCollectionAddError < CalculatedFieldCollectionError; end
    end
  end
end
