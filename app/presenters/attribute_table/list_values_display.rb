module AttributeTable
  # Basically just takes a list of Strings and formats them into a <ul>, for our show page.
  #
  # Optionally can make each one a link to a search on a specified facet limit.
  class ListValuesDisplay < ViewModel
    valid_model_type_names "Array" # of String, but we can't enforce that at present

    attr_reader :link_to_facet
    alias_method :string_array, :model

    def initialize(model, link_to_facet: false)
      @link_to_facet = link_to_facet
      super(model)
    end


    def display
      return "" if string_array.blank?

      content_tag("ul") do
        safe_join(
          string_array.map do |str|
            content_tag("li", html_value(str), class: "attribute")
          end
        )
      end
    end

    private

    def html_value(str)
      if link_to_facet
        link_to str, search_on_facet_path(link_to_facet, str)
      else
        str
      end
    end
  end
end
