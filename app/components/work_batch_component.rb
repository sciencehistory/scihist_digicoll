# frozen_string_literal: true

# The standard image-centered work show page, used for works by default, when
# we don't have a special purpose work show page.

class WorkBatchComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  delegate :transcription_texts,   :translation_texts, :has_transcription_or_translation?,  to: WorkImageShowComponent

  attr_reader :work , :work_download_options

  NUMBER_OF_WORKS_PER_BATCH = 100


  def initialize(work, batch:1, work_download_options:)
    @work = work
    @batch = batch
    @work_download_options = work_download_options
  end

  #TODO use this method instead, instead of the template
  # def call
  #   member_list_for_display.each_with_index do |member_for_thumb, index| 
  #     content_tag("div", class: ['show-member-list-item']) do
  #       #lazyload all but first 6 images, supply an image_label for accessible labels
  #       MemberImageComponent.new(member_for_thumb.member, lazy: (index > 5), image_label: member_for_thumb.image_label).call
  #     end
  #   end
  # end

  # TODO DRY: slightly modified from WorkImageShowComponent
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
        WorkImageShowComponent::MemberForThumbnailDisplay.new(member: member, image_label: "Image #{start_image_number + index}")
      end
    end
  end

  # TODO DRY: slightly modified from WorkImageShowComponent
  # All DISPLAYABLE (to current user) members, in order, and
  # with proper pre-fetches.
  def ordered_viewable_members
    @ordered_viewable_members ||= work.
                          ordered_viewable_members(current_user: current_user).
                          where("role is null OR role != ?", PdfToPageImages::SOURCE_PDF_ROLE)
  end

  # TODO: DRY: this method exists already in work_image_show_component - why can't we use delegate here?
  #
  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImageComponent. This will be an additional SQL fetch to
  # member_list_for_display, but a small targetted one-result one.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)
    @representative_member = (work.representative.try(:role) != PdfToPageImages::SOURCE_PDF_ROLE) ?  work.representative : nil
  end

end
