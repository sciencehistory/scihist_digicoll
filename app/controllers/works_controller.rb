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

  # TODO  don't calculate work_download_options a bunch of times.
  def lazy_member_images
    @start_index = params[:start_index].to_i
    @images_per_page = params[:images_per_page].to_i
    ordered_viewable_members = @work.ordered_viewable_members(current_user: current_user, exclude_pdf_source: true)

    # todo -- instead of slice use some activerecord stuff...
    @slice = ordered_viewable_members.
      slice(@start_index, @images_per_page).
      collect.with_index do |member, index|
        # Todo: check that start_index is correct here
        WorkImageShowComponent::MemberForThumbnailDisplay.new(member: member, image_label: "Image #{@start_index + index}")
    end

    respond_to do |format|
      format.html {
        render :layout => false
      }
    end
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

  # We use a different ViewComponent depending on work characteristics, polymorophically kind of.
  def view_component
    @view_component ||= if @work.is_oral_history? && @work.oral_history_content&.available_by_request_off? && has_oh_audio_member?
      # special OH audio player template
      WorkOhAudioShowComponent.new(@work)
    elsif @work.is_oral_history?
      # OH with no playable audio, either becuae it's by-request or it's not there at all.
      WorkFileListShowComponent.new(@work)
    elsif has_video_representative?
      WorkVideoShowComponent.new(@work)
    else
      # standard image-based template.
      ordered_viewable_members = @work.ordered_viewable_members(current_user: current_user, exclude_pdf_source: true)
      WorkImageShowComponent.new(@work, ordered_viewable_members:ordered_viewable_members)
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

  # used for determining whether to use our video display component
  def has_video_representative?
    return @has_video_representative if defined?(@has_video_representative)

    @work.leaf_representative&.content_type&.start_with?("video/")
  end

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end
end
