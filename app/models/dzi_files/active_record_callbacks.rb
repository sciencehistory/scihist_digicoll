class DziFiles
  # Just a container for some methods used as ActiveRecord callbacks for
  # DZI lifecycle management. Registered on Asset class in after_commit
  # and after_promotion registrations.
  module ActiveRecordCallbacks
    def self.after_promotion(asset)
      # we're gonna use the same kithe promotion_directives for derivatives to
      # control how we do dzi
      Kithe::TimingPromotionDirective.new(
          key: :create_derivatives,
          directives: asset.file_attacher.promotion_directives) do |directive|

        if directive.inline?
          DziFiles.new(asset).create
        elsif directive.background?
          CreateDziJob.perform_later(asset)
        end
      end
    end

    def self.after_commit(asset)
      if asset.destroyed?
        if asset.md5.blank?
          Rails.logger.warn("Deleting file without an md5, can't find/delete DZI: #{asset.friendlier_id || asset.id}")
          return
        end

        # we're gonna use the same kithe promotion_directives for :delete to
        # control how we do dzi deletion too.
        Kithe::TimingPromotionDirective.new(
            key: :delete,
            directives: asset.file_attacher.promotion_directives) do |directive|

          if directive.inline?
            asset.dzi_file.delete
          elsif directive.background?
            DeleteDziJob.perform_later(asset.dzi_file.dzi_uploaded_file.id)
          end
        end
      else
        # file changed, need to delete an old dzi?
        old_file_data, new_file_data = asset.file_data_previous_change
        if old_file_data.present?
          if old_file_data.kind_of?(String) # not sure why this happens, it should be JSON already
            old_file_data = JSON.parse(old_file_data)
          end
          if old_file_data["id"] != new_file_data["id"] &&
             old_md5 = old_file_data.dig("metadata", "md5")

             old_id = DziFiles.new(asset, md5: old_md5).dzi_uploaded_file.id
             DeleteDziJob.perform_later(old_id)
           end
        end
      end
    end
  end
end
