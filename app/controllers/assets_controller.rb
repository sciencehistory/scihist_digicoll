class AssetsController < ApplicationController

  def ingest_direct_files_input
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

    redirect_to members_for_work_url(@parent.friendlier_id)
  end

  private

  def kithe_upload_data_config
    data = {
      toggle: "kithe-upload"
    }
    if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
      data[:s3_storage] = "cache"
      data[:s3_storage_prefix] = Shrine.storages[:cache].prefix
    end
    data
  end
  helper_method :kithe_upload_data_config

end
