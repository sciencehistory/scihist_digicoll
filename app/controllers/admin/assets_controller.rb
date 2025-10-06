class Admin::AssetsController < AdminController

  def index
    # No authorize! call here. We're assuming if you can view the
    # index, you can see all published and unpublished collections.
    scope = Asset

    # simple simple search on a few simple attributes with OR combo.
    if params[:q].present?
      scope = scope.where(id: params[:q]).or(
        Asset.where(friendlier_id: params[:q])
      ).or(
        Asset.where("title like ?", "%" + Asset.sanitize_sql_like(params[:q]) + "%")
      )
    end

    if params[:promotion_failed] == "true"
      scope = scope.promotion_failed
    end

    scope = scope.page(params[:page]).per(20).order(created_at: :desc)
    scope = scope.includes(:parent)

    @assets = scope
  end

  def show
    @asset = Asset.find_by_friendlier_id!(params[:id])
    authorize! :read, @asset

    @exiftool_result = Kithe::ExiftoolCharacterization.presenter_for(@asset&.exiftool_result)

    getter = MemberPreviousAndNextGetter.new(@asset)
    @previous_url, @next_url = getter.previous_url, getter.next_url

    if @asset.stored?
      @checks = @asset.fixity_checks.order('created_at asc')
      @latest_check   = @checks.last
      @earliest_check = @checks.first
    end
  end

  def edit
    @asset = Asset.find_by_friendlier_id!(params[:id])
    authorize! :update, @asset
  end

  # PATCH/PUT /works/1
  # PATCH/PUT /works/1.json
  def update
    @asset = Asset.find_by_friendlier_id!(params[:id])
    authorize! :update, @asset

    respond_to do |format|
      if @asset.update(asset_params)
        # If this update changed suppress_ocr, enqueue a job to update
        # the entire parent work's OCR.
        # Reprocessing the entire work based on changes to a single asset
        # seems like overkill.
        # In practice, this operation is cheap and keeps the code DRY.
        if @asset.suppress_ocr_previously_changed?
          WorkOcrCreatorRemoverJob.perform_later(@asset.parent)
        end
        format.html { redirect_to admin_asset_url(@asset), notice: 'Asset was successfully updated.' }
        format.json { render :show, status: :ok, location: @asset }
      else
        format.html { render :edit }
        format.json { render json: @asset.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @asset = Asset.find_by_friendlier_id!(params[:id])
    authorize! :destroy, @asset

    if @asset.parent
      # doing it this way will update @asset.parent.members in-memory, so it's consistent and the
      # destroyed work is not in the in-memory association, which can matter for instance
      # for the automatic reindexing after this save!
      @asset.parent.members.destroy(@asset)
    else
      @asset.destroy
    end

    respond_to do |format|
      format.html { redirect_to admin_work_path(@asset.parent.friendlier_id, anchor: "tab=nav-members"), notice: "Asset '#{@asset.title}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def check_fixity
    @asset = Asset.find_by_friendlier_id!(params[:asset_id])
    SingleAssetCheckerJob.perform_later(@asset)
    redirect_to admin_asset_url(@asset), notice: 'This file will be checked shortly.'
  end

  def new_fixity_report
    CalculateFixityReportJob.perform_later
    redirect_to admin_fixity_report_path(new_report_started: true)
  end

  def fixity_report
    minutes_before_allowing_recalc = 0
    @latest_report = FixityReport.new.report_from_cache
    @new_report_started = params[:new_report_started]
    @allow_recalc  = (@latest_report.present? && ((Time.now - DateTime.parse(@latest_report[:timestamp])).to_i / 60) > minutes_before_allowing_recalc)
  end

  def display_attach_form
    @parent = Work.find_by_friendlier_id!(params[:parent_id])
    authorize! :update, @parent
  end

  # Receives json hashes for direct uploaded files in params[:files],
  # and parent_id in params[:parent_id] (friendlier_id)
  # creates filesets for them and attach.
  #
  # POST /admin/works/[parent_work.friendlier_id]/ingest
  def attach_files
    @parent = Work.find_by_friendlier_id!(params[:parent_id])
    authorize! :update, @parent

    current_position = @parent.members.maximum(:position) || 0

    files_params = (params[:cached_files] || []).
      collect { |s| JSON.parse(s) }.
      sort_by { |h| h && h.dig("metadata", "filename")}

    files_params.each do |file_data|
      asset = Asset.new()

      if derivative_storage_type = params.dig(:storage_type_for, file_data["id"])
        asset.derivative_storage_type = derivative_storage_type
      end

      asset.position = (current_position += 1)
      asset.parent_id = @parent.id
      asset.file = file_data
      asset.title = (asset.file&.original_filename || "Untitled")
      asset.published = @parent.published
      asset.save!
    end

    if @parent.representative_id == nil
      @parent.update(representative: @parent.members.order(:position).first)
    end

    redirect_to admin_work_path(@parent.friendlier_id, anchor: "nav-members")
  end

  def convert_to_child_work
    @asset = Asset.find_by_friendlier_id!(params[:id])

    parent = @asset.parent

    new_child = Work.new(title: @asset.title)

    # Asking for permission to create a new Work,
    # which is arguably the main thing going on in this method.
    # authorize! :create, Work as the first line of the method
    # would be better, but we currently aren't allowed to do that
    # see (https://github.com/chaps-io/access-granted/pull/56).
    authorize! :create, new_child

    new_child.parent = parent
    # collections
    new_child.contained_by = parent.contained_by
    new_child.position = @asset.position
    new_child.representative = @asset
    # we can copy _all_ the non-title metadata like this...
    new_child.json_attributes = parent.json_attributes

    @asset.parent = new_child

    Kithe::Model.transaction do
      new_child.save!
      @asset.save! # to get new parent

      if parent.representative_id == @asset.id
        parent.representative = new_child
        parent.save!
      end
    end

    redirect_to edit_admin_work_path(new_child), notice: "Asset promoted to child work #{new_child.title}"
  end

  # PUT /admin/asset_files/:id/setup_work_from_pdf_source
  #
  # Will try to take this PDF asset, and extract all it's pages into extracted page assets, also
  # setting some work and asset metadata properly for those roles.
  def setup_work_from_pdf_source
    @asset = Asset.find_by_friendlier_id!(params[:id])

    errors = []
    unless @asset.content_type == "application/pdf"
      errors << "This asset is not a PDF, so cannot be used"
    end
    unless @asset.stored?
      errors << "This asset is not fully ingested, please try again later"
    end
    if @asset.parent.text_extraction_mode == "ocr"
      errors << "This asset's work parent is set to `ocr` text_extraction_mode, which is incompatible with PDF-sourced work."
    end
    already = @asset.members.where(role: PdfToPageImages::SOURCE_PDF_ROLE).where("id != ?", @asset.id).first
    if already
      errors << "There is already an asset in parent work with role `work_source_pdf, there can't be more than one. See #{already.friendlier_id}"
    end

    if errors.present?
      redirect_to admin_asset_path(@asset), flash: { error: "Could not make PDF work, see errors below", make_work_source_pdf_errors: errors }
      return
    end

    page_count = @asset.file_metadata["page_count"]

    @asset.update!(role: PdfToPageImages::SOURCE_PDF_ROLE)
    @asset.parent.update!(text_extraction_mode: "pdf_extraction")

    1.upto(page_count).each do |page_num|
      CreatePdfPageImageAssetJob.perform_later(@asset, page_num)
    end

    # if we don't have a scaled_down_pdf derivative yet, kick off a job for that too!
    unless @asset.file_derivatives[AssetUploader::SCALED_PDF_DERIV_KEY].present?
      CreateScaledDownPdfDerivativeJob.perform_later(@asset)
    end

    redirect_to admin_asset_path(@asset), flash: { success: "Started creation of PDF page assets, it could take a few minutes to complete." }
  end

  # requires params[:active_encode_status_id]
  def refresh_active_encode_status
    status = ActiveEncodeStatus.find(params[:active_encode_status_id])

    RefreshActiveEncodeStatusJob.perform_later(status)

    redirect_to admin_asset_url(status.asset), notice: "Started refresh for ActiveEncode job #{status.active_encode_id}"
  end

  # PATCH/PUT /admin/asset_files/ab2323ac/submit_hocr_and_textonly_pdf
  def submit_hocr_and_textonly_pdf
    @asset = Asset.find_by_friendlier_id!(params[:id])
    authorize! :update, @asset
    begin
      AssetHocrAndPdfUploader.new(@asset).attach(hocr: params[:hocr], textonly_pdf: params[:textonly_pdf])
    rescue AssetHocrAndPdfUploaderError => e
      redirect_to admin_asset_url(@asset), flash: { error: e.message }
      return
    end
    redirect_to admin_asset_url(@asset), flash: { notice: "Updated HOCR and textonly_pdf." }
  end

  def work_is_oral_history?
    (@asset.parent.is_a? Work) && @asset.parent.genre && @asset.parent.genre.include?('Oral histories')
  end
  helper_method :work_is_oral_history?

  def asset_is_collection_thumbnail?
    @asset.parent.is_a? Collection
  end
  helper_method :asset_is_collection_thumbnail?

  def edit_path(asset)
    (asset.parent.is_a? Collection) ? edit_admin_collection_path(asset.parent) : edit_admin_asset_path(asset)
  end
  helper_method :edit_path

  def parent_path(asset)
    return nil if asset.parent.nil?
    (asset.parent.is_a? Collection) ? collection_path(asset.parent) : admin_work_path(asset.parent)
  end
  helper_method :parent_path


  private

  def asset_params
    allowed_params = [:title, :derivative_storage_type, :alt_text, :caption,
      :transcription, :english_translation, :suppress_ocr, :ocr_admin_note, :new_report_started,
      :role, {admin_note_attributes: []}]
    allowed_params << :published if can?(:publish, @asset)
    asset_params = params.require(:asset).permit(*allowed_params)
  end

end
