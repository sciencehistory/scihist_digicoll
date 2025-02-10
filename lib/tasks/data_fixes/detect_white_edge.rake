namespace :scihist do
  namespace :data_fixes do

    desc """
      Calculate white edge detected for specific WORK_FRIENDLIER_ID
    """
    task :detect_white_edge => :environment do
      detector = DetectWhiteImageEdge.new

      scope = Work.find_by_friendlier_id(ENV['WORK_FRIENDLIER_ID']).members
      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.each do |asset|
        progress_bar.increment

        next unless asset.kind_of?(Asset)

        # let's detect on a quicker to download derivative

        asset.file_derivatives[:thumb_large].download do |file|
          asset.file_metadata[AssetUploader::WHITE_EDGE_DETECT_KEY] = detector.call(file.path)
          asset.save!
        end
      end
    end
  end
end
