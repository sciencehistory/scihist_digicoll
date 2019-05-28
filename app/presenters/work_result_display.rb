class WorkResultDisplay < ViewModel
  delegate :additional_title

  def display
    render "/presenters/index_result", model: model, view: self
  end

  def display_genres
    @display_genres ||= safe_join(
      model.genre.map { |g| link_to g, search_on_facet_path(:genre_facet, g) },
      ", "
    )
  end

  def display_dates
    @display_dates = DateDisplayFormatter.new(model.date_of_work).display_dates
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

  # An array of elements for "part of" listing, includes 'parent' in a link,
  # or "source" in italics
  def part_of_elements
    @part_of_elements ||= [].tap do |arr|
      if model.parent.present?
        arr << link_to(model.parent.title, work_path(model.parent))
      end
      if model.source.present?
        arr << content_tag("i", model.source)
      end
    end
  end
end
