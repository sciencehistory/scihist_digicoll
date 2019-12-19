class Admin::AssetsController < AdminController

  def show
    @asset = Asset.find_by_friendlier_id!(params[:id])
    if @asset.stored?
      @checks = @asset.fixity_checks.order('created_at asc')
      @latest_check   = @checks.last
      @earliest_check = @checks.first
    end
  end

  def edit
    @asset = Asset.find_by_friendlier_id!(params[:id])
  end

  # PATCH/PUT /works/1
  # PATCH/PUT /works/1.json
  def update
    @asset = Asset.find_by_friendlier_id!(params[:id])

    respond_to do |format|
      if @asset.update(asset_params)
        format.html { redirect_to admin_asset_url(@asset), notice: 'Asset was successfully updated.' }
        format.json { render :show, status: :ok, location: @asset }
      else
        format.html { render :edit }
        format.json { render json: @asset.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @asset = Asset.find_by_friendlier_id!(params[:id])

    authorize! :destroy, @asset

    work = @asset.parent
    @asset.destroy
    respond_to do |format|
      format.html { redirect_to admin_work_path(work.friendlier_id, anchor: "nav-members"), notice: "Asset '#{@asset.title}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def check_fixity
    @asset = Asset.find_by_friendlier_id!(params[:asset_id])
    SingleAssetCheckerJob.perform_later(@asset)
    redirect_to admin_asset_url(@asset), notice: 'This file will be checked shortly.'
  end

  def fixity_report
    @fixity_report = FixityReport.new()
  end

  def display_attach_form
    @parent = Work.find_by_friendlier_id!(params[:parent_id])
  end

  # Receives json hashes for direct uploaded files in params[:files],
  # and parent_id in params[:parent_id] (friendlier_id)
  # creates filesets for them and attach.
  #
  # POST /admin/works/[parent_work.friendlier_id]/ingest
  def attach_files
    @parent = Work.find_by_friendlier_id!(params[:parent_id])

    current_position = @parent.members.maximum(:position) || 0

    files_params = (params[:cached_files] || []).
      collect { |s| JSON.parse(s) }.
      sort_by { |h| h && h.dig("metadata", "filename")}

    files_params.each do |file_data|
      asset = Asset.new
      asset.position = (current_position += 1)
      asset.parent_id = @parent.id
      asset.file = file_data
      asset.title = (asset.file&.original_filename || "Untitled")
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

  private

  def asset_params
    allowed_params = [:title]
    allowed_params << :published if can?(:publish, @asset)

    asset_params = params.require(:asset).permit(*allowed_params)
  end
end
