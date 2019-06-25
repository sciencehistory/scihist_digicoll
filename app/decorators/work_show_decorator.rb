class WorkShowDecorator < Draper::Decorator
  delegate_all
  include Draper::LazyHelpers

  def display_genres
    safe_join(
      model.genre.map { |g| link_to g, search_on_facet_path(:genre_facet, g) },
      ", "
    )
  end

  # Like chf_sufia, it only looks at content types from direct Asset children, it
  # won't go down levels. That has been good enough.
  def humanized_content_types
    @humanized_content_types ||= model.members.
      find_all { |m| m.kind_of?(Asset) }.
      map(&:content_type).
      map { |a| ScihistDigicoll::Util.humanized_content_type(a) }
  end

  def related_urls_filtered
    related_url_filter.filtered_related_urls
  end

  # from related_url (legacy), or from our external_id with bib IDs in it.
  def links_to_opac
    @links_to_opac ||= begin
      bib_ids = (model.external_id || []).find_all do |external_id|
        external_id.category == "bib"
      end.map(&:value)

      (bib_ids + related_url_filter.opac_ids).map do |bib_id|
        RelatedUrlFilter.opac_url(bib_id)
      end
    end
  end

  # Our creators are a list of Work::Creator object. We want to group them by
  # category, in a hash where the values are a list of all things with that
  # same category.
  #
  # And the hash will be sorted by the order we want to display.
  #
  # @returns [Hash] key a symbol Work::Creator category, value a list of String values
  def grouped_creators
    @grouped_creators ||= begin
      grouped = model.creator.group_by(&:category).transform_values! do |value_array|
        value_array.map(&:value)
      end

      desired_order = [:artist, :attributed_to, :author, :addressee, :creator_of_work, :editor,
        :engraver, :interviewee, :interviewer, :manner_of, :manufacturer, :photographer, :contributor,
        :after, :printer, :printer_of_plates, :publisher
      ]

      grouped.sort_by { |k, v| desired_order.index(k) || 10000 }.to_h
    end
  end

  # Our places are a list of Work::Place object. We want to group them by
  # category, in a hash where the values are a list of all things with that
  # same category.
  #
  # And the hash will be sorted by the order we want to display.
  #
  # @returns [Hash] key a symbol Work::Place category, value a list of String values
  def grouped_places
    @grouped_places ||= begin
      grouped = model.place.group_by(&:category).transform_values! do |value_array|
        value_array.map(&:value)
      end

      desired_order = [:place_of_creation, :place_of_interview, :place_of_manufacture, :place_of_publication]

      grouped.sort_by { |k, v| desired_order.index(k) || 10000 }.to_h
    end
  end

  # We'll pull ID's out of any self-pointing URLs in our `related_urls`, and then fetch
  # works for them. Yes, this is a kind of crazy legacy way of storing/getting this data,
  # but it's what we got for now.
  #
  # I guess we don't care about the order?
  #
  # Make sure to prefetch leaf_representatives and it's derivatives, so we can display
  # without n+1 fetch.
  def related_works
    @related_works ||= Work.where(
        friendlier_id: related_url_filter.related_work_friendlier_ids,
        published: true
      ).includes(leaf_representative: :derivatives).all
  end

  def public_collections
    @work.contained_by.where(published: true)
  end

  private

  def related_url_filter
    @related_url_filter ||= RelatedUrlFilter.new(model.related_url)
  end
end
