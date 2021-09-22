# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :check_auth

  def show
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
    end
  end

  def viewer_images_info
    render json: ViewerMemberInfoSerializer.new(@work).as_hash
  end

  private


  # We use a different ViewComponent depending on work characteristics, polymorophically kind of.
  def view_component
    @decorator ||= if @work.is_oral_history? && @work.oral_history_content&.available_by_request_off? && has_oh_audio_member?
      # special OH audio player template
      WorkOhAudioShowComponent.new(@work)
    elsif @work.is_oral_history?
      # OH with no playable audio, either becuae it's by-request or it's not there at all.
      WorkFileListShowComponent.new(@work)
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
    # The Decorators are going to fetch members again anyway, we're kind of fetching
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

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end
end
