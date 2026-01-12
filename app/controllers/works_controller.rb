# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :check_auth

  def show
    @show_deai_header = true

    respond_to do |format|
      format.html {
        render view_component
      }

      format.xml {
        render body: WorkOaiDcSerialization.new(@work).to_oai_dc, type: :xml
      }

      format.ris {
        send_data RisSerializer.new(@work).to_ris,
          disposition: 'attachment',
          filename: DownloadFilenameHelper.ris_download_name(@work),
          type: :ris
      }

      format.json {
        render body: WorkJsonSerializer.new(
          @work,
        ).serialize
      }
    end
  end

  # lazy_member_images.js calls this method on work pages with lots of members.
  # Returns a page containing just member images, which lazy_member_images.js retrieves and inserts into the DOM.
  # Takes an offset and a limit.
  # See also WorkImageShowComponent, which shows the first batch of images and provides the script with what it needs.
  def lazy_member_images
    if !(params[:start_index] =~ /\A\d+\Z/) || !(params[:members_per_batch]  =~ /\A\d+\Z/ )
      render :nothing => true, :layout => false
      return
    end

    @start_index = params[:start_index].to_i
    @members_per_batch = params[:members_per_batch].to_i
    @lazy_member_images = ordered_viewable_members_excluding_pdf_source.
      offset(@start_index).
      limit(@members_per_batch).
      strict_loading.
      collect.with_index do |member, i|
        WorkImageShowComponent::MemberForThumbnailDisplay.new(member: member, image_label: "Image #{@start_index + i}")
    end
    @total_count = @ordered_viewable_members_excluding_pdf_source.count
    @more_pages_to_load = @start_index + @members_per_batch <= @total_count

    render :layout => false
  end

  def viewer_images_info
    render json: ViewerMemberInfoSerializer.new(@work,
        show_unpublished: can?(:read, Kithe::Model)
      ).as_hash
  end

  def viewer_search
    if params[:q].blank?
      render status: 422, json: { error: "Error status 422: Missing required `q` parameter." } and return
    end

    render json: HocrSearcher.new(@work, query: params[:q],
        show_unpublished: can?(:read, Kithe::Model)
    ).results_for_osd_viewer
  rescue HocrSearcher::EmptyQueryError => e
    render status: 422, json: { error: "Error status 422: q parameter: #{e.message}." } and return
  end

  def transcription
    send_data(
      TransTextPdf.new(@work, mode: :transcription).prawn_pdf.render,
      filename: DownloadFilenameHelper.work_download_name(@work, specifier_str: "transcription", suffix: "pdf"),
      type: 'application/pdf',
      disposition: (params["disposition"] == "attachment" ? :attachment : :inline)
    )
  end

  def english_translation
    send_data(
      TransTextPdf.new(@work, mode: :english_translation).prawn_pdf.render,
      filename: DownloadFilenameHelper.work_download_name(@work, specifier_str: "english_translation", suffix: "pdf"),
      type: 'application/pdf',
      disposition: (params["disposition"] == "attachment" ? :attachment : :inline)
    )
  end

  private

  def ordered_viewable_members_excluding_pdf_source
    @ordered_viewable_members_excluding_pdf_source ||=  @work.
      ordered_viewable_members_excluding_pdf_source(current_user: current_user)
  end

  # We use a different ViewComponent depending on work characteristics, polymorophically kind of.
  def view_component
    @view_component ||= if @work.is_oral_history? && @work.oral_history_content&.available_by_request_off? && has_oh_audio_member?
      # special OH audio player template
      WorkOhAudioShowComponent.new(@work)

    elsif @work.is_oral_history?
      # OH with no playable audio, either becuae it's by-request or it's not there at all.
      WorkFileListShowComponent.new(@work)

    elsif show_video_player?
      WorkVideoShowComponent.new(@work)
    else
      # standard image-based template.
      WorkImageShowComponent.new(@work)
    end
  end

  # Is an Oral History with at least one audio member?
  def has_oh_audio_member?
    # memoize for boolean value
    return @has_oh_audio_member if defined?(@has_oh_audio_member)

    # some pg JSON operators in our WHERE clause to pull out actually just
    # what we want.
    #
    # The ViewComponents are going to fetch members again anyway, we're kind of fetching
    # content that will be fetched again -- but oh well, we do it nice and efficiently!
    #
    # We have to do two queries to get all the mime-types, one for where the direct member
    # is an asset, and another for where it's a child work and we have to follow leaf_representative
    #
    # We use Arel.sql cause if we don't we get a deprecation message telling us:
    #     "Dangerous query method... Known-safe values can be passed by wrapping them in Arel.sql()""
    @has_oh_audio_member ||= begin
      if ! @work.genre && @work.genre.include?("Oral histories")
        false
      else
        direct_types = @work.members.
          where(published: true).
          distinct.pluck(Arel.sql("file_data -> 'metadata' -> 'mime_type'")).
          compact

        indirect_types = @work.members.
          where(published: true).
          joins(:leaf_representative).
          distinct.pluck(Arel.sql("leaf_representatives_kithe_models.file_data -> 'metadata' -> 'mime_type'")).
          compact

        (direct_types + indirect_types).any? { |t| t.start_with?("audio/")}
      end
    end
  end

  def show_video_player?
    @work.format.include?('moving_image') && @work.members.any? { |m| m&.content_type&.start_with?("video/") }
  end

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end
end
