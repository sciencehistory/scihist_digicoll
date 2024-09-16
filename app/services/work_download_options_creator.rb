# Based on work characteristics, figure out whole work download options
#
# We try to do this efficiently, but it can be expensive -- so when you have lots of menus
# on a page with this, re-use one of these objects that has cached the expensive calculation?
#
# have a PUBLISHED parent work, with more than 1 child, and AT LEAST ONE of it's children are images,
# provide multi-image downloads. These are the only whole-work-download options we provide at present.
#
# (Our current PDF and Zip creators only create for published items, they can't create
# for non-published items. But we don't currently have an easy way to efficiently access
# number of published child items, we just use the parent being unpublished as a proxy
# for "not ready")
#
class WorkDownloadOptionsCreator
  attr_reader :work, :options

  def initialize(work:)
    @work = work
    @options = construct_options
  end

  protected

  def has_constructed_pdf?
    return @has_constructed_pdf if defined? @has_constructed_pdf

    # if we AT LEAST one child, and all children are images, is how we've done this
    # historically, may have to be changed as our uses change! May have just been doing this for efficiency?
    #
    # Not sure why we are delivering PDF for single page image with no OCR, but we are! for consistency?
    @has_constructed_pdf = work && work.published? && work_member_count > 0 && work_member_content_types.all? { |c| c.start_with?("image/")}
  end

  def has_constructed_zip?
    return @has_constructed_zip if defined? @has_constructed_zip

    # if we have more than one child, and all children are images, is how we've done this
    # historically, may have to be changed as our uses change! May have just been doing this for efficiency?
    @has_constructed_zip = work && work.published? && work_member_count > 1 && work_member_content_types.all? { |c| c.start_with?("image/")}
  end


  def construct_options
    options = []

    if has_constructed_pdf?
      options << DownloadOption.for_on_demand_derivative(
        label: "PDF", derivative_type: "pdf_file", work_friendlier_id: work.friendlier_id
      )
    end

    if has_constructed_zip?
      options << DownloadOption.for_on_demand_derivative(
        label: "ZIP", derivative_type: "zip_file", work_friendlier_id: work.friendlier_id
      )
    end

    options
  end

  def work_member_content_types
    return @work_has_image_members if defined? @work_has_image_members

    @work_has_image_members = if work.members.loaded?
      # search in memory cause they're already all loaded
      work.members.collect { |member| member.leaf_representative&.content_type }.compact.uniq
    else
      # go to DB with an efficient fetch
      work.members.
          includes(:leaf_representative).
          references(:leaf_representative).
          pluck(Arel.sql("
            DISTINCT leaf_representatives_kithe_models.file_data -> 'metadata' -> 'mime_type', kithe_models.file_data -> 'metadata' -> 'mime_type'"
          )).flatten.compact.uniq
    end
  end

  def work_member_count
    @work_member_count ||= work.member_count
  end

end
