class Admin::AssetsController < ApplicationController

  # intended for staff, not sure if we will hide it
  def show
    @asset = Asset.find_by_friendlier_id(params[:id])
  end

  def edit
    @asset = Asset.find_by_friendlier_id!(params[:id])
  end

  # PATCH/PUT /works/1
  # PATCH/PUT /works/1.json
  def update
    @asset = Asset.find_by_friendlier_id!(params[:id])
    asset_params = params.require(:asset).permit(:title)

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
    @asset = Asset.find_by_friendlier_id(params[:id])
    work = @asset.parent
    @asset.destroy
    respond_to do |format|
      format.html { redirect_to admin_work_url(work.friendlier_id), notice: "Asset '#{@asset.title}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def display_attach_form
    @parent = Work.find_by_friendlier_id(params[:parent_id])
  end

  # Receives json hashes for direct uploaded files in params[:files],
  # and parent_id in params[:parent_id] (friendlier_id)
  # creates filesets for them and attach.
  def attach_files
    @parent = Work.find_by_friendlier_id(params[:parent_id])

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

    redirect_to admin_work_url(@parent.friendlier_id)
  end

  private

  def kithe_upload_data_config
    data = {
      toggle: "kithe-upload",
      upload_endpoint: admin_direct_app_upload_path
    }

    if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
      data[:s3_storage] = "cache"
      data[:s3_storage_prefix] = Shrine.storages[:cache].prefix
    end

    data
  end
  helper_method :kithe_upload_data_config

end
