# Display the right column of a work show page including, metadata attributes,
# physical location, 'related items'.
#
# In a partial to make it easier to re-use in templates that differ in how
# they show media, but still need this.
#
# For flexibility, does NOT include abstract/description, which usually comes
# above here, or the "cite as" which usually comes below.
#
#
# CAREFUL: rendering this template can trigger a request to SOLR.
# See #more_like_this_works below for details.
#
#
class WorkShowInfoComponent < ApplicationComponent
  # Delegate through to WORK
  delegate :additional_credit, :additional_title,
    :contained_by, :date_of_work, :department,
    :description, :digitization_funder, :extent, :exhibition,
    :format, :genre, :inscription, :language, :medium,
    :parent, :physical_container, :provenance, :published?,
    :rights, :rights_holder, :series_arrangement,
    :source, :subject, :title, to: :work

  delegate :current_staff_user?, to: :helpers

  attr_reader :work

  def initialize(work:)
    @work = work
  end

  def display_genres
    safe_join(
      work.genre.map { |g| link_to g, search_on_facet_path(:genre_facet, g) },
      ", "
    )
  end

  def related_links
    related_link_filter.general_related_links
  end

  # from  our external_id with bib IDs in it.
  def links_to_opac
    @links_to_opac ||= begin
      # bib_ids are supposed to be `b` followed by 7 numbers, but sometimes
      # extra digits get in, cause Siera staff UI wants to add em, but
      # they won't work for links to OPAC, phew.
      bib_ids = (work.external_id || []).find_all do |external_id|
        external_id.category == "bib"
      end.map(&:value).map { |id| id.slice(0,8) }

      bib_ids.collect(&:downcase).uniq.map do |bib_id|
        ScihistDigicoll::Util.opac_url(bib_id)
      end
    end
    @links_to_opac
  end

  def links_to_finding_aids
    @links_to_finding_aids ||= related_link_filter.finding_aid_related_links.collect(&:url).compact
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
      grouped = work.creator.group_by(&:category).transform_values! do |value_array|
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
      grouped = work.place.group_by(&:category).transform_values! do |value_array|
        value_array.map(&:value)
      end

      desired_order = [:place_of_creation, :place_of_interview, :place_of_manufacture, :place_of_publication]

      grouped.sort_by { |k, v| desired_order.index(k) || 10000 }.to_h
    end
  end

  def related_or_more_like_this_works
    @related_or_more_like_this_works ||= related_works.present? ? related_works : more_like_this_works
  end

  # We'll pull ID's out of our related_links for related_works, and then fetch
  # works for them.
  #
  # I guess we don't care about the order?
  #
  # Make sure to prefetch leaf_representatives and it's derivatives, so we can display
  # without n+1 fetch.
  def related_works
    @related_works ||= Work.where(
        friendlier_id: related_link_filter.related_work_friendlier_ids,
        published: true
      ).includes(:leaf_representative).all
  end

  # This triggers a single request to SOLR to retrieve works deemed similar.
  # This is unusual, but calling the code in the controller turned out to be unduly complex.
  def more_like_this_works
    @more_like_this_works ||= MoreLikeThisGetter.new(work, max_number_of_works: 3).works
  end

  def public_collections
    work.contained_by.where(published: true)
  end

  def oral_history_interviewer_profiles
    return @oral_history_interviewer_profiles if defined?(@oral_history_interviewer_profiles)

    if work.is_oral_history? && work.oral_history_content.present?
      @oral_history_interviewer_profiles = work.oral_history_content.interviewer_profiles
    else
      @oral_history_interviewer_profiles = []
    end

    return @oral_history_interviewer_profiles
  end

  def oral_history_number
    @oral_history_number ||= work.external_id.find { |id| id.category == "interview"}&.value
  end

  private

  def related_link_filter
    @related_link_filter ||= RelatedLinkFilter.new(work.related_link)
  end

end
