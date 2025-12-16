module GoogleArtsAndCulture
  class GoogleArtsAndCulture::KitheModelSerializer
    def initialize(model, callback: nil, attribute_keys:, column_counts: )
      @model = model
      @callback = callback
      @column_counts = column_counts
      @attribute_keys = attribute_keys
    end

    # Return zero, one or more values of metadata, padded as needed.
    def scalar_or_padded_array(arr_or_string, count_of_columns_needed: )
      # no value: return no_value (empty string).
      return no_value if arr_or_string.nil?

      # one value: return a string
      return arr_or_string if arr_or_string.is_a? String

      raise "Too many values" if arr_or_string.length > count_of_columns_needed

      # return multiple values, padding if needed so that the array spans the correct number of columns.
      return arr_or_string if arr_or_string.length == count_of_columns_needed
      arr_or_string.concat(Array.new(count_of_columns_needed - arr_or_string.length, padding))
    end

    def test_mode
      false
    end

    def padding
      test_mode ? 'PADDING' : ''
    end

    def no_value
      test_mode ? 'NO_VALUE' : ''
    end

    def not_applicable
      test_mode ? 'N/A' : ''
    end

  end
end