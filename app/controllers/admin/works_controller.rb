# Managers UI for creating and editing works.
#
# Started with generated code from Rails 5.2 scaffold.
#
# We'll probably handle `show` in a different controller, for now no show.
#
# There's a lot of Oral history specific special purpose stuff in here, which should
# prob be moved to a different controller.
class Admin::WorksController < AdminController
  before_action :set_work,
    only: [:show, :edit, :update, :destroy, :reorder_members,
           :reorder_members_form, :demote_to_asset, :publish, :unpublish,
           :submit_ohms_xml, :download_ohms_xml, :set_review_requested,
           :remove_ohms_xml, :submit_searchable_transcript_source, :download_searchable_transcript_source,
           :remove_searchable_transcript_source, :create_combined_audio_derivatives, :update_oh_available_by_request,
           :update_oral_history_content, :store_input_docx_transcript, :get_output_sequenced_docx_transcript]

  before_action :sort_link_maker, only: [:index]

  # GET /admin/works
  # GET /admin/works.json
  def index
    # No authorize! call here. We're assuming if you can view the
    # index, you can see all published and unpublished works.
    @works = build_search(index_params)
    @cart_presence = CartPresence.new(@works.collect(&:friendlier_id), current_user: current_user)
  end

  def sort_link_maker
    @sort_link_maker ||= SortedTableHeaderLinkComponent.link_maker params: index_params
  end
  helper_method :sort_link_maker

  def index_params
    @index_params ||= params.permit(
      :button,
      :sort_field, :sort_order, :department, :page,
      :title_or_id, :published, :genre, :work_format, :include_child_works,
      :ocr_requested, :review_requested
    ).tap do |hash|
      unless hash[:sort_field].in? ['friendlier_id', 'title', 'created_at', 'updated_at']
        hash[:sort_field] = "updated_at"
      end
      unless hash[:sort_order].in? ['asc', 'desc']
        hash[:sort_order] = "desc"
      end
      if hash[:department].present? && !hash[:department].in?(Work::ControlledLists::DEPARTMENT)
        raise ArgumentError.new("Unrecognized department: #{hash[:department]}")
      end
      if hash[:genre].present? && !hash[:genre].in?(Work::ControlledLists::GENRE)
        raise ArgumentError.new("Unrecognized genre: #{hash[:genre]}")
      end

      # format is a reserved word
      # (see https://stackoverflow.com/questions/70726614/ruby-on-rails-use-format-as-a-url-get-parameter )
      # so let's use work_format instead.
      if hash[:work_format].present? && !hash[:work_format].in?(Work::ControlledLists::FORMAT)
        raise ArgumentError.new("Unrecognized format: #{hash[:work_format]}")
      end

      unless hash[:include_child_works] == "true"
        hash[:include_child_works] = "false"
      end
      [:published, :ocr_requested].each do |k|
        if hash[k].present? && !hash[k].in?(['true', 'false'])
          raise ArgumentError.new("Value not allowed for #{k}: #{hash[k]}")
        end
      end
      if hash[:review_requested].present? && !hash[:review_requested].in?(['requested', 'by_others'])
        raise ArgumentError.new("Value not allowed for review_requested: #{hash[k]}")
      end
    end
  end

  # GET /admin/works/new
  def new
    @work = Work.new
    authorize! :create, @work

    if params[:digitization_queue_item]
      queue_item = Admin::DigitizationQueueItem.find(params[:digitization_queue_item])
      @work.digitization_queue_item_id = queue_item.id
      queue_item.fill_out_work(@work)
    end

    if params[:parent_id]
      @parent_work = Work.find_by_friendlier_id!(params[:parent_id])
      @work.parent = @parent_work
      @work.contained_by = @parent_work.contained_by
      @work.position = (@parent_work.members.maximum(:position) || 0) + 1
    end

    render :edit
  end

  # GET /admin/works/1/edit
  def edit
    authorize! :update, @work
  end

  # POST /admin/works
  # POST /admin/works.json
  def create
    @work = Work.new(work_params)
    authorize! :create, @work

    if @work.parent_id && @work.position.nil?
      @work.position = (@work.parent.members.maximum(:position) || 0) + 1
    end

    respond_to do |format|
      if @work.save
        format.html { redirect_to admin_asset_ingest_path(@work), notice: 'Work was successfully created, would you like to add files now?' }
        format.json { render :show, status: :created, location: @work }
      else
        format.html { render :edit }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/works/1
  # PATCH/PUT /admin/works/1.json
  def update
    authorize! :update, @work
    respond_to do |format|
      if @work.update(work_params)
        # If this update also just switched ocr_requested, queue up a job to update its OCR
        # data accordingly. If for some reason this is missed, we still have a nightly rake
        # task to restore consistent state, but let's try to do it sooner.
        if @work.text_extraction_mode_previously_changed?
          WorkOcrCreatorRemoverJob.perform_later(@work)
        end

        format.html { redirect_to admin_work_path(@work), notice: 'Work was successfully updated.' }
        format.json { render :show, status: :ok, location: @work }
      else
        format.html { render :edit }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/works/ab2323ac/set_review_requested
  def set_review_requested
    review_requested = (params[:review_requested] == "1")
    @work.review_requested = review_requested

    if review_requested
      @work.review_requested_by = current_user.email
      @work.review_requested_at = DateTime.now
    else
      @work.review_requested_by = nil
      @work.review_requested_at = nil
    end

    @work.save!
    redirect_to admin_work_path(@work)
  end

  # comes in as a file multipart POST, we read it and stick it in ohms_xml text field please
  # PATCH/PUT /admin/works/ab2323ac/submit_ohms_xml
  def submit_ohms_xml
    authorize! :update, @work
    unless params[:ohms_xml].present?
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), flash: { error: "No file received" }
      return
    end

    xml = params[:ohms_xml].read
    validator = OralHistoryContent::OhmsXmlValidator.new(xml)

    if validator.valid?
      @work.oral_history_content!.update!(ohms_xml_text: xml)
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), notice: "OHMS XML file updated"
    else
      Rails.logger.debug("Could not accept invalid OHMS XML for work #{@work.friendlier_id}:\n  #{xml.slice(0, 60).gsub(/[\n\r]/, '')}...\n\n  #{validator.errors.join("\n  ")}")
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), flash: {
        error: "OHMS XML file was invalid and could not be accepted: #{validator.errors.join('; ')}"
      }
    end
  end

  def store_input_docx_transcript
    authorize! :update, @work

    # Store file to shrine in normal way. Clear out output that won't go with any new file.
    @work.oral_history_content!.output_sequenced_docx_transcript = nil
    @work.oral_history_content!.input_docx_transcript = params[:docx]
    @work.oral_history_content.save!

    SequenceOhTimestampsJob.perform_later(@work)

    redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), notice: "Input .docx transcript sequencing started..."
  end

  def get_output_sequenced_docx_transcript
    authorize! :update, @work

    unless @work.oral_history_content.output_sequenced_docx_transcript.present?
      raise ActionController::RoutingError.new('Not Found')
    end

    # one way to stream it?
    response.headers['Content-Type'] = @work.oral_history_content.output_sequenced_docx_transcript.metadata["mime_type"]
    response.headers['Content-Disposition'] = ContentDisposition.format(disposition: "attachment", filename: @work.oral_history_content.output_sequenced_docx_transcript.metadata["filename"])
    stream = @work.oral_history_content.output_sequenced_docx_transcript.to_io
    stream.each_chunk do |chunk|
      response.stream.write chunk
    end
  ensure
    stream.close if stream
  end

  # PATCH/PUT /admin/works/ab2323ac/remove_ohms_xml
  def remove_ohms_xml
    authorize! :update, @work
    @work.oral_history_content!.update!(ohms_xml_text: nil)
    redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), notice: "OHMS XML file removed."
  end

  # GET /admin/works/ab2323ac/download_ohms_xml
  def download_ohms_xml
    authorize! :read, @work
    send_data @work.oral_history_content!.ohms_xml_text,
      :type => 'text/xml; charset=UTF-8;',
      :disposition => ContentDisposition.format(disposition: "attachment", filename: "#{@work.oral_history_content!.ohms_xml.accession}.xml")
  end

  # PATCH/PUT /admin/works/ab2323ac/submit_ohms_xml
  def submit_searchable_transcript_source
    authorize! :update, @work
    unless params[:searchable_transcript_source].present?
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), flash: { error: "No file received" }
      return
    end
    transcript = params[:searchable_transcript_source].read
    # Assume UTF-8 if the browser/rails didn't tell us anything, as it apparently does not
    transcript.force_encoding("UTF-8") if transcript.encoding == Encoding::BINARY

    # make sure we have an OralHistoryContent sidecar
    @work.oral_history_content!

    searchable_transcript_source_error = nil

    # Validate some things, add them to ActiveRecord errors
    unless params[:searchable_transcript_source].content_type.start_with?('text/')
      searchable_transcript_source_error = "Could not accept this file: it's not a text file."
    end

    if searchable_transcript_source_error.nil? && ! transcript.valid_encoding?
      searchable_transcript_source_error = "Expected encoding #{transcript.encoding}, but does not look valid for #{transcript.encoding}!"
    end

    if searchable_transcript_source_error.nil?
      @work.oral_history_content.update!(searchable_transcript_source: transcript)
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), notice: "Full text has been updated."
    else
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), flash: {
        error: "Transcript not updated: #{searchable_transcript_source_error}",
        searchable_transcript_source_error: "Transcript not updated: #{searchable_transcript_source_error}"
      }
    end
  end

  # PATCH/PUT /admin/works/ab2323ac/remove_searchable_transcript_source
  def remove_searchable_transcript_source
    authorize! :update, @work
    @work.oral_history_content!.update!(searchable_transcript_source: nil)
    redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), notice: "Full text has been removed."
  end

  # GET /admin/works/ab2323ac/download_searchable_transcript_source
  def download_searchable_transcript_source
    authorize! :read, @work
    id = @work.external_id.find { |id| id.category == "interview" }&.value
    id ||= @work.friendlier_id
    filename =  "#{id}_transcript.txt"
    send_data @work.oral_history_content!.searchable_transcript_source,
      :type => 'text/plain; charset=UTF-8;',
      :disposition => ContentDisposition.format(disposition: "attachment", filename: filename)
  end

  # Create_combined_audio_derivatives in the background, if warranted.
  # PATCH/PUT /admin/works/ab2323ac/create_combined_audio_derivatives
  def create_combined_audio_derivatives
    authorize! :update, @work
    deriv_creator = CombinedAudioDerivativeCreator.new(@work)
    unless deriv_creator.available_members?
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), flash: {
        error: "Combined audio derivatives cannot be created, because this oral history does not have any published audio segments."
      }
      return
    end

    if deriv_creator.audio_metadata_errors.present?
      Rails.logger.warn("Unable to create a combined audio derivative for work #{@work.friendlier_id} due to bad metadata:\n  #{deriv_creator.audio_metadata_errors.join("\n  ")}")
      redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), flash: {
        error: "Combined audio derivatives cannot be created: something is wrong with at least one of the audio segments. Details: " + deriv_creator.audio_metadata_errors.join("; ")
      }
      return
    end

    CreateCombinedAudioDerivativesJob.perform_later(@work)
    sidecar = @work.oral_history_content!
    sidecar.combined_audio_derivatives_job_status = 'queued'
    sidecar.save!

    notice = "The combined audio derivative job has been added to the job queue."
    redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories"), notice: notice
  end

  # PUT /admin/works/ab2323ac/update_oh_available_by_request
  def update_oh_available_by_request
    authorize! :update, @work
    @work.transaction do
      @work.oral_history_content!.update( params.require(:oral_history_content).permit(:available_by_request_mode))

      params[:available_by_request]&.each_pair do |asset_pk, value|
        @work.members.find{ |m| m.id == asset_pk}&.update(oh_available_by_request: value)
      end
    end
    redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories")
  end

  # PATCH /admin/works/ab2323ac/update_oral_history_content
  def update_oral_history_content
    authorize! :update, @work
    @work.oral_history_content!.update(
      params.require(:oral_history_content).permit(interviewer_profile_ids: [], interviewee_biography_ids: [])
    )

    # This action can update the which IntervieweeBiographies are linked, which changes
    # indexing. Other OralHistoryContent could also be indexed. But there is no
    # automatic model-callback based reindexing of Work based on changes in associated
    # OralHistoryContent, so we trigger it here ourselves in controller action.
    @work.update_index

    redirect_to admin_work_path(@work, anchor: "tab=nav-oral-histories")
  end

  # PATCH/PUT /admin/works/1/publish
  #
  # publishes work AND all of it's children (multi-level).
  #
  # fetches all children so rails callbacks will be called, but uses postgres
  # recursive CTE so it'll be efficient-ish.
  def publish
    authorize! :publish, @work

    # Check for invalid files:
    #  e.g. zero-length files
    # or jpgs that should really be tiffs.

    unpublishable_file_info = unpublishable_file_info([@work])
    unless unpublishable_file_info[:works].empty?
      redirect_to admin_work_path(@work, anchor: "tab=nav-members"), flash: {
        error: "Can't publish this work. The following assets have unpublishable files: #{unpublishable_file_info[:asset_ids].join '; '}"
      }
      return
    end

    @work.class.transaction do
      @work.update!(published: true)
      if params[:cascade] == 'true'
        @work.all_descendent_members.find_each do |member|
          member.update!(published: true)
        end
      end
    end

    redirect_to admin_work_url(@work)

  rescue ActiveRecord::RecordInvalid => e
    # probably because missing a field required for a work to be published, but
    # could apply to a CHILD work, not just the parent you actually may have clicked 'publish'
    # on.
    #
    # The work we're going to report and redirect to is just the FIRST one we encountered
    # with an error, there could be more.
    @work = e.record
    @work.published = true
    flash.now[:error] = "Can't publish work: #{@work.title}: #{e.message}"
    render :edit
  end

  # PUT /admin/works/1/unpublish
  #
  # unpublishes work AND all of it's children (multi-level) using a pg recursive CTE
  #
  # fetches all children so rails callbacks will be called, but uses postgres
  # recursive CTE so it'll be efficient-ish.
  def unpublish
    authorize! :publish, @work

    @work.class.transaction do
      @work.update!(published: false)
      if params[:cascade] == 'true'
        @work.all_descendent_members.find_each do |member|
          member.update!(published: false)
        end
      end
    end
    redirect_to admin_work_url(@work)
  end

  # DELETE /works/1
  # DELETE /works/1.json
  def destroy
    authorize! :destroy, @work
    @work.destroy
    respond_to do |format|
      format.html { redirect_to cancel_url, notice: "Work '#{@work.title}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # Our admin 'show' page is really the members index.
  def show
    authorize! :read, @work
    @cart_presence = CartPresence.new([@work.friendlier_id], current_user: current_user)

    # instantiate this in an iVar so we can use it in two different places in template,
    # without double instantiation or double load of SQL query inside. A little bit hacky,
    # but this works out.
    @work_admin_text_extract_info_component = WorkAdminTextExtractInfoComponent.new(@work)
  end

  def reorder_members_form
    authorize! :update, @work
  end

  # triggered from members reorder form,
  #
  # A) Accessed with HTTP put (meaning Rails fakes it with :method hidden field),
  # we want an array of member IDs (UUIDs)
  # in params[:ordered_member_ids][]. All with the same parent, the one specified
  # in params[:id].
  #
  # B) Accessed via HTTP get without params[:ordered_member_ids], we'll sort
  # alphbetically.
  def reorder_members
    authorize! :update, @work
    if params[:ordered_member_ids]
      ActiveRecord::Base.transaction do
        params[:ordered_member_ids].each_with_index do |id, index|
          Kithe::Model.find(id).update(position: index)
        end
      end
    else # alphabetical
      sorted_members = @work.members.sort_by{ |member| member.title.downcase  }.to_a
      ActiveRecord::Base.transaction do
        sorted_members.each_with_index do |member, index|
          member.update(position: index)
        end
      end
    end

    redirect_to admin_work_url(params[:id], anchor: "nav-members")
  end

  def self.can_demote_to_asset?(work)
    work.parent.present? &&
      work.parent.kind_of?(Work) &&
      work.members.size == 1 &&
      work.members.first.kind_of?(Asset)
  end

  def demote_to_asset
    unless self.class.can_demote_to_asset?(@work)
      redirect_to admin_work_path(@work), alert: "Can't convert this work to an Asset"
      return
    end

    authorize! :destroy, @work

    parent = @work.parent
    # a bit of race condition here if someone else added an asset in the meantime,
    # it'll be lost. no big deal at present, unclear right way to solve.
    #
    # Also surprisingly hard to make sure rails doesn't delete the asset when we
    # delete the parent, even though we've re-homed the asset, due to dependent destroy. grr.
    # The reset says we'll get the first right from db, without a cached list of members,
    # and it'll refetch list of members later for dependent destroy. :(
    asset = @work.members.reset.first

    asset.position = @work.position
    asset.parent = @work.parent

    Kithe::Model.transaction do
      if parent.representative_id == @work.id
        parent.representative = asset
        parent.save!
      end

      asset.save!
      @work.destroy
    end

    redirect_to admin_work_path(asset.parent, anchor: "nav-members"), notice: "Child work replaced with asset #{asset.title}"
  end

  # Display a form for entry for batch editing all works in Cart. Convenient
  # to put it in WorksController so we can re-use our work form partials.
  def batch_update_form
    # authorize! :update, Work would make more sense here,
    # but we currently aren't allowed to do that
    # see (https://github.com/chaps-io/access-granted/pull/56).
    authorize! :update, Kithe::Model
    # Create a dummy blank Work to power the form
    # The BatchUpdateWorkForm object will remove 'presence'
    # validators so the form won't show any
    # fields as required.
    @work = Admin::BatchUpdateWorkForm.new({})
  end

  # Accepts input from batch_update_form, to apply to all items in cart.
  def batch_update
    # authorize! :update, Work would make more sense here,
    # but we currently aren't allowed to do that
    # see (https://github.com/chaps-io/access-granted/pull/56).
    authorize! :update, Kithe::Model
    @work = Admin::BatchUpdateWorkForm.new(work_params)
    # Since we're going to end up solr re-indexing em all, let's make sure
    # and avoid n+1s.
    works_scope = current_user.works_in_cart.strict_loading.for_batch_indexing

    # Plus we ALSO need to pre-load contained_by if we're going to edit it!
    # I don't feel like setting contained_by_ids ought to load or require
    # loading contained_by... yet strict_loading said it did, works for now.
    if work_params.has_key?(:contained_by_ids)
      works_scope = works_scope.includes(:contained_by)
    end

    unless @work.update_works(works_scope.find_each)
      # the form is based on @work, so re-rendered will show errors
      render :batch_update_form
      return
    end

    redirect_to admin_cart_items_url, notice: "Updated works in Cart. It may take a few minutes for changes to be visible in public search."
  end

  def batch_publish_toggle
    # authorize! :publish, Work would make more sense here,
    # but we currently aren't allowed to do that
    # see (https://github.com/chaps-io/access-granted/pull/56).
    authorize! :publish, Kithe::Model

    unless params[:publish].in?(["on", "off"])
      raise ArgumentError.new("Need `publish` param to be `on` or off`")
    end

    # Check works in cart for invalid files.
    unpublishable_file_info = unpublishable_file_info(current_user.works_in_cart)
    unless unpublishable_file_info[:works].empty?
      example_work = unpublishable_file_info[:works].first
      redirect_to admin_cart_items_url, flash: { error: "No changes made due to error: \"#{example_work.title}\" (#{example_work.friendlier_id}) contains one or more assets with invalid files." }
      return
    end
    publish_value = params[:publish] == "on"

    Work.transaction do
      current_user.works_in_cart.find_each do |work|
        work.update!(published: publish_value)
        if params[:cascade] == 'true'
          work.all_descendent_members.find_each do |member|
            member.update!(published: true)
          end
        end
      end
    end

    message = "#{publish_value ? "Published" : "UN-published"} all items"
    message += " (and their members)" if params[:cascade]

    redirect_to admin_cart_items_url, notice: message
  rescue ActiveRecord::RecordInvalid => e
    # probably because missing a field required for a work to be published, but
    # could apply to a CHILD work, not just the parent you actually may have clicked 'publish'
    # on.
    #
    # The work we're going to report and redirect to is just the FIRST one we encountered
    # with an error, there could be more.
    work = e.record
    redirect_to admin_cart_items_url, flash: { error: "No changes made due to error: \"#{work.title}\" (#{work.friendlier_id}): #{e.message}" }
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_work
      @work = Work.includes(:leaf_representative).find_by_friendlier_id!(params[:id])
    end

    def prevent_deleting_parent_representative
      if @work.parent.present? && @work.parent.representative == @work && @work.parent.published?
        respond_to do |format|
          notice = "Could not destroy work '#{@work.title}'. '#{@work.parent.title}' is published and this is its representative."
          format.html { redirect_to admin_work_path(@work.friendlier_id, anchor: "tab=nav-members"), notice: notice }
          format.json { render json: { error: notice }, status: 422 }
        end
      end
    end

    # Check all asset members of an array of works
    # (ignoring their child works) for assets with invalid files.
    # Details are noted in the logs, and a hash with problem works and problem asset_ids are returned.
    def unpublishable_file_info(work_array)
      problem_works = Set.new
      problem_asset_ids = Set.new

      cols = [
        "kithe_models.friendlier_id",
        "kithe_models.file_data -> 'metadata' -> 'promotion_validation_errors'",
        "kithe_models.file_data -> 'metadata' -> 'mime_type'",
        "kithe_models.role",
      ].join(",")

      Asset.where(parent: work_array).pluck(Arel.sql(cols)).each do |row|
        asset_id, promotion_errors, mime_type, role = *row
        if promotion_errors.present?
          parent = Asset.find_by_friendlier_id(asset_id).parent
          Rails.logger.warn("Work '#{parent.friendlier_id}' couldn't be published. Something was wrong with the file for asset '#{asset_id}.'")
          problem_works << parent
          problem_asset_ids << asset_id
        end
        # Image assets published as part of a work need to be tiffs, except if they are in an identified special role
        if mime_type.nil? || mime_type.start_with?('image/') && mime_type != 'image/tiff' && !role.in?(['portrait', 'extracted_pdf_page'])
          problem = mime_type.nil? ? "has no mime_type" : "is a #{mime_type} instead"
          parent = Asset.find_by_friendlier_id(asset_id).parent
          Rails.logger.warn("Work '#{parent.friendlier_id}' couldn't be published. Asset '#{asset_id}' should be an image/tiff, but #{problem}.")
          problem_works << parent
          problem_asset_ids << asset_id
        end
      end
      { works: problem_works, asset_ids: problem_asset_ids }
    end


    # only allow whitelisted params through (TODO, we're allowing all work params!)
    # Plus sanitization or any other mutation.
    #
    # This could be done in a form object or otherwise abstracted, but this is good
    # enough for now.
    def work_params
      @work_params ||= begin
        # Remove leading and trailing whitespace from values that may have been submitted
        # from input forms where it's easy to accidentally include.
        #
        # It's a bit hard to do this without interfering with Rails ActionController::Parameters,
        # but this seems to work here.
        #
        # We cast a pretty wide net, removing from MOST parameters. That seems to work,
        # we can't think of any where it might cause a problem, but if it does, we
        # can come back and try to make this more sophisticcated logic.
        recursive_strip_whitespace!(params["work"])

        Kithe::Parameters.new(params).require(:work).permit_attr_json(Work).permit(
          :title, :ocr_requested, :parent_id, :representative_id, :digitization_queue_item_id, :contained_by_ids => []
        ).tap do |params|
          # sanitize description & provenance
          [:description, :provenance].each do |field|
            if params[field].present?
              params[field] = DescriptionSanitizer.new.sanitize(params[field])
            end
          end
        end
      end
    end

    # Recursively descend through nested array/hash, take all strings and mutate
    # to strip! leading or trailing whitespace
    #
    # We ignore certain deny-listed TOP-LEVEL terms, customized for our
    # use case -- `description` and `admin_notes_attributes` -- those often
    # end in newlines, we don't really care, for legacy reasons we'll leave them
    # there.
    def recursive_strip_whitespace!(obj, top_level: true)
      if obj.is_a?(Hash) || obj.is_a?(ActionController::Parameters)
        obj.each_pair do |k, v|
          next if top_level and k.in?(["description", "admin_note_attributes"])

          recursive_strip_whitespace!(v, top_level: false)
        end
      elsif obj.is_a?(Array)
        obj.each { |v| recursive_strip_whitespace!(v, top_level: false)}
      elsif obj.is_a?(String)
        obj.strip!
      end
    end

    def cancel_url
      if @work && @work.parent
        return admin_work_path(@work.parent)
      end

      if @work && @work.persisted?
        return admin_work_path(@work)
      end

      admin_works_path
    end
    helper_method :cancel_url

    # Searching, filtering, and pagination for the #index method
    def build_search(params)
      scope = Work.all
      if params[:title_or_id].present?
        match_ilike = Work.sanitize_sql_like params[:title_or_id]
        match_uuid = Work.type_for_attribute(:id).cast(params[:title_or_id])
        match_any_external_id = "[{ \"value\" : #{params[:title_or_id].to_json} }]"
        scope = scope.where(
          [
            "title ILIKE ?",
            "friendlier_id ILIKE ?",
            "id = ?",
            "json_attributes -> 'external_id' @> ?::jsonb",
          ].join(" OR "),
          match_ilike, match_ilike, match_uuid, match_any_external_id
        )
      end

      if params[:genre].present?
        scope = scope.where("json_attributes -> 'genre' ? :genre", genre: params[:genre])
      end

      # format is a reserved word
      # (see https://stackoverflow.com/questions/70726614/ruby-on-rails-use-format-as-a-url-get-parameter )
      # so let's use work_format instead.
      if params[:work_format].present?
        scope = scope.where("json_attributes -> 'format' ? :work_format", work_format: params[:work_format])
      end


      if params[:department].present?
        scope = scope.where("json_attributes ->> 'department' = :department", department: params[:department])
      end
      if params[:review_requested].present?
        scope = scope.jsonb_contains(review_requested: true)
        if params[:review_requested] == "by_others"
          scope = scope.not_jsonb_contains(review_requested_by: current_user.email )
        end
      end
      if params[:ocr_requested] == 'true'
        scope = scope.jsonb_contains(text_extraction_mode: "ocr")
      elsif params[:ocr_requested] == 'false'
        scope = scope.not_jsonb_contains(text_extraction_mode: "ocr")
      end
      if params[:published] == 'true'
        scope = scope.where(published: true)
      elsif params[:published] == 'false'
        scope = scope.where(published: false)
      end
      if params[:include_child_works] == 'false'
        scope = scope.where("parent_id IS NULL")
      end
      scope.order!(index_params[:sort_field] => index_params[:sort_order])
      scope.includes(:leaf_representative).page(params[:page]).per(20)
    end
end

