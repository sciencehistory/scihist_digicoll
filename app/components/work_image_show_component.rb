# frozen_string_literal: true

# The standard image-centered work show page, used for works by default, when
# we don't have a special purpose work show page.

# If you pass in images_per_page, we will only show that number of thumbnails.
# The template will also include an invisible span giving the JS code on the front end
# the start index at which to start retrieving more thumbnails.

class WorkImageShowComponent < ApplicationComponent
  delegate :construct_page_title, :current_user, to: :helpers

  attr_reader :work, :work_download_options, :images_per_page

  def initialize(work, images_per_page:100)
    @work = work
    @images_per_page = images_per_page

    # work download options are expensive, so we calculate them here so we can use them
    # in several places
    @work_download_options = WorkDownloadOptionsCreator.new(work).options
  end

  def ordered_viewable_members
    ordered_viewable_members ||= @work.
      ordered_viewable_members_excluding_pdf_source(current_user: current_user)
  end

  def more_pages_to_load?
    total_count > images_per_page
  end

  def total_count
    ordered_viewable_members.count
  end


  # Zero-based start index for next batch of thumbnails, if needed.
  def start_index
    images_per_page
  end

  # Public members, ordered, to be displayed as thumbnails
  # underneath the hero/representative image -- excluding the hero if it's the
  # first item in ordered list, cause it looks messy to show it twice in a row,
  # especially when we only have 2 or especially one member!
  #
  # We need to provide accessible labels to actions for images in list,
  # and the best we can do is "Image 1", "Image 2", "Image 10" etc.
  #
  # What that label is depends on if we excluded the representative or not though.
  # So we return MemberForThumbnailDisplay objects that have both the "member"
  # (Work or Asset), AND it's accessible label eg "Image 5"
  #
  def member_list_for_display
    @member_list_display ||= begin
      members = ordered_viewable_members
      members = members.limit(images_per_page) if more_pages_to_load?
      members = members.to_a
      # If the representative image is the first item in the list, don't show it twice.
      start_image_number = 1
      if members[0] == representative_member
        members.delete_at(0)
        start_image_number = 2
      end

      members.collect.with_index do |member, index|
        MemberForThumbnailDisplay.new(member: member, image_label: "Image #{start_image_number + index}")
      end
    end
  end

  def transcription_texts
    @transcription_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :transcription)
  end

  def translation_texts
    @translation_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :english_translation)
  end

  def has_transcription_or_translation?
    # at least one 'english_translation' or 'transcription' that is not NULL and not empty string
    @has_transcription_or_translation ||= ordered_viewable_members.
      where("NULLIF(json_attributes ->> 'english_translation', '') is not null OR NULLIF(json_attributes ->> 'transcription', '') is not null").
      exists?
  end


  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImageComponent. This will be an additional SQL fetch to
  # member_list_for_display, but a small targetted one-result one.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)

    @representative_member = (work.representative.try(:role) != PdfToPageImages::SOURCE_PDF_ROLE) ?  work.representative : nil
  end

  # A weird helper method to lset us conditionally sometimes wrap
  # the work description in TranslationTabsComponent, other times not.
  #
  #   <%= maybe_wrap_with_component(wrapping_component: WrappingComponent.new, should_wrap: boolean) do %>
  #      More content that may or may not be wrapped.
  #   <% end %>
  def maybe_wrap_with_component(wrapping_component:, should_wrap:)
    if should_wrap
      render wrapping_component do
        yield
      end
    else
      yield
    end
  end

  # Encapsulates a member (Asset or Work), and an `image_label` like
  # "Image 5" that we use as a "best we've got" accessible label for
  # acitons like "Download Image 5"
  class MemberForThumbnailDisplay
    attr_reader :member, :image_label

    def initialize(member:, image_label:)
      @member = member
      @image_label = image_label
    end
  end
end
