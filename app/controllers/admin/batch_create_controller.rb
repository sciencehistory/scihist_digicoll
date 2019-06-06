class Admin::BatchCreateController < AdminController

  # Find views from works controller and assets controller too, since we re-use em
  def self.local_prefixes
    super + ["admin/works", "admin/assets"]
  end

  # the first step, metadata creation form
  def new
    @work = Work.new
    if params[:digitization_queue_item]
      queue_item = Admin::DigitizationQueueItem.find(params[:digitization_queue_item])
      @work.digitization_queue_item_id = queue_item.id
      queue_item.fill_out_work(@work)
    end
  end

  # second step, gets metadata attributes POSTed in a serialized
  # JSON hash in params[:work], displays a form for file picking,
  # that then POSTS the carried over work metadata and (direct-uploaded)
  # file information to last step, #create
  def add_files
    # validate
    @work = Work.new(work_params.merge(title: "batch create placeholder"))
    if !@work.valid?
      render :new
      return
    end

  end

  # Gets direct-uploaded file information and work information, creates
  # a buncha files.
  def create
    extracted_work_params = work_params({work: JSON.parse(params[:work_metadata_json])})

    files_params = (params[:cached_files] || []).
      collect { |s| JSON.parse(s) }.
      sort_by { |h| h && h.dig("metadata", "filename")}

    Kithe::Model.transaction do
      files_params.each do |file_data|
        asset = Asset.new
        asset.file = file_data
        asset.title = (asset.file&.original_filename || "Untitled")
        asset.save!

        work = Work.new(extracted_work_params)
        work.title = asset.title
        work.representative = asset
        work.save!

        asset.parent = work
        asset.save!
      end
    end

    redirect_to admin_works_path, notice: "#{helpers.pluralize(files_params.count, "work")} batch created."
  end

  private

  # Copied from WorkController, but without :title, :representative_id, or :parent_id
  # we prob should DRY somehow, at least the sanitizing
  def work_params(p = params)
    Kithe::Parameters.new(p).require(:work).permit_attr_json(Work).permit(
      :digitization_queue_item_id, :contained_by_ids => []
    ).tap do |params|
      # sanitize description & provenance
      [:description, :provenance].each do |field|
        if params[field].present?
          params[field] = DescriptionSanitizer.new.sanitize(params[field])
        end
      end
    end
  end
  helper_method :work_params # so we can serialize and pass on

  helper_method def cancel_url
    admin_works_path
  end

  helper_method def kithe_upload_data_config
    Admin::AssetsController.kithe_upload_data_config
  end

end
