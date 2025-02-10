# frozen_string_literal: true

# The standard image-centered work show page, used for works by default, when
# we don't have a special purpose work show page.

class WorkBatchComponent < ApplicationComponent
  delegate :construct_page_title, :current_user, to: :helpers

  attr_reader :work , :work_download_options

  NUMBER_OF_WORKS_PER_BATCH = 100


  def initialize(work, batch:1)
    @work = work
    @batch = batch

    @work_download_options = WorkDownloadOptionsCreator.new(work).options
  end


  # using an html.erb template for now.
  # TODO use this method instead.
  # def call
  #   member_list_for_display.each_with_index do |member_for_thumb, index| 
  #     content_tag("div", class: ['show-member-list-item']) do
  #       #lazyload all but first 6 images, supply an image_label for accessible labels
  #       MemberImageComponent.new(member_for_thumb.member, lazy: (index > 5), image_label: member_for_thumb.image_label).call
  #     end
  #   end
  # end

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
      members = ordered_viewable_members.page(@batch).per(NUMBER_OF_WORKS_PER_BATCH).to_a
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

  # All DISPLAYABLE (to current user) members, in order, and
  # with proper pre-fetches.
  def ordered_viewable_members
    @ordered_viewable_members ||= work.
                          ordered_viewable_members(current_user: current_user).
                          where("role is null OR role != ?", PdfToPageImages::SOURCE_PDF_ROLE)
  end

  def transcription_texts
    @transcription_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :transcription)
  end

  def translation_texts
    @translation_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :english_translation)
  end

  def has_transcription_or_translation?
    transcription_texts.present? || translation_texts.present?
  end


  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImageComponent. This will be an additional SQL fetch to
  # member_list_for_display, but a small targetted one-result one.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)
    @representative_member = (work.representative.try(:role) != PdfToPageImages::SOURCE_PDF_ROLE) ?  work.representative : nil
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
