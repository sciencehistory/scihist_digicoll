module AttributeTable
  # Displays a <tr> with heading in <th> and values in a list in <td>.
  #
  # For use in our styled attribute table for work show page.
  #
  # Values can link to facet.
  #
  # If no values, returns empty string.
  #
  # For now it will use rails #humanize to turn a symbol passed in as label
  # into a displayable string. In the future, we can add i18n if needed.
  #
  #     RowDisplay.new(:subject, values: array_of_strings, link_to_facet: "subject_facet").display
  #
  class RowDisplay < ViewModel
    attr_reader :label_sym, :values, :link_to_facet

    # @param alpha_sort [Boolean] if true, sort values alphabetically. Default false.
    def initialize(label_sym, link_to_facet: false, values: nil, alpha_sort: false)
      @label_sym = label_sym
      @values = (values || []).reject {|v| v.blank? }
      @link_to_facet = link_to_facet
      @alpha_sort =  alpha_sort

      # gotta give it something, we aren't really using this.
      super("Foobar")
    end

    def display
      return "" unless values.present?

      content_tag("tr") do
        safe_join([
          content_tag("th", label_cell_content),
          content_tag("td", value_cell_content)
        ])
      end
    end

    private

    def label_cell_content
      label_sym.to_s.humanize
    end

    def value_cell_content
      ListValuesDisplay.new((@alpha_sort ? values.sort : values), link_to_facet: link_to_facet).display
    end
  end
end
