class AssetsController < ApplicationController

  def ingest_direct_files_input
    @parent = Work.find_by_friendlier_id(params[:parent_id])
  end

  # Receives json hashes for direct uploaded files in params[:files],
  # and parent_id in params[:parent_id] (friendlier_id)
  # creates filesets for them and attach.
  def attach_files
    @parent = Work.find_by_friendlier_id(params[:parent_id])

    (params[:cached_files] || []).each do |file_data|
      asset = Kithe::Asset.new
      asset.parent_id = @parent.id
      asset.file = file_data
      asset.title = (asset.file&.original_filename || "Untitled")
      asset.save!
    end

    redirect_to members_for_work_url(@parent.friendlier_id)
  end

end
