module SearchResult
  # Displays an element in search results for a "Work"
  #
  # * requires a a ChildCountDisplayFetcher for efficient fetching and provision of "N Items"
  # child count on display.
  class WorkComponent < BaseComponent
    delegate :additional_title, to: :model

    def display_genres
      @display_genres ||= render(GenreLinkListComponent.new(model.genre))
    end

    def display_dates
      @display_dates = DateDisplayFormatter.new(model.date_of_work).display_dates
    end

    def display_num_children_and_extent
      content_tag("div", class: "scihist-results-list-item-num-members") do
        (display_extent + display_num_children).join(", ")
      end
    end

    def display_num_children
      count = child_counter.display_count_for(model)
      return [] unless count > 1
      [ number_with_delimiter(count) + ' item'.pluralize(count) ]
    end

    def display_extent
      return [] unless model&.format.include?('moving_image')
      model&.extent || []
    end

    def thumbnail_html
      render ThumbComponent.new(model.leaf_representative)
    end

    def link_to_href
      work_path(model)
    end

    # Returns a hash of lables and values for display on the tabular metadata field, for
    # subjects and creators.
    #
    # The keys are the labels to use for the metadata field, actual literals (if i18n needed,
    # do it internal here)
    #
    # The values of the hash are an ARRAY of 1 more values. Each of those values CAN be html_safe
    # HTML, for instance a link to a search.
    def metadata_labels_and_values
      unless @metadata_labels_and_values
        @metadata_labels_and_values = {}

        # Add creators, with creator categories separated but multiple values
        # for same creator category grouped.
        model.creator.each do |creator_obj|
          label = creator_obj.category.titlecase # could be i18n here instead
          @metadata_labels_and_values[label] ||= []
          @metadata_labels_and_values[label] << link_to(creator_obj.value, search_on_facet_path(:creator_facet, creator_obj.value))
        end

        # Add subjects
        if model.subject.present?
          @metadata_labels_and_values["Subject"] = model.subject.collect do |subject|
            link_to(subject, search_on_facet_path(:subject_facet, subject))
          end
        end
        @metadata_labels_and_values.freeze
      end

      return @metadata_labels_and_values
    end

    # An array of elements for "part of" listing, includes 'parent' in a link.
    #
    # (Used to handle more possibilities is why this is written abstractly like this)
    def part_of_elements
      if model.parent.present?
        [link_to(model.parent.title, work_path(model.parent))]
      else
        []
      end
    end

    def show_cart_control?
      can? :access_staff_functions
    end
  end
end
