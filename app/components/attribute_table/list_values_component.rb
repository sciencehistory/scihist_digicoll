module AttributeTable
  # Basically just takes a list of Strings and formats them into a <ul>, for our show page.
  #
  # Optionally can make each one a link to a search on a specified facet limit.
  class ListValuesComponent < ApplicationComponent
    delegate :search_on_facet_path, to: :helpers

    attr_reader :link_to_facet, :string_array

    def initialize(string_array, link_to_facet: false)
      @link_to_facet = link_to_facet
      @string_array = string_array
    end

    def render?
      string_array.present?
    end

    def call
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
