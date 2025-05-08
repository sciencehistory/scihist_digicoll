class DziPackage
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
          DziPackage.new(asset).create
        elsif directive.background?
          CreateDziJob.perform_later(asset)
        end
      end
    end

    def self.after_commit(asset)
      if asset.destroyed?
        if asset.dzi_manifest_file.blank?
          Rails.logger.warn("Deleting file without a dzi_manifest_file listed, can't find/delete DZI: #{asset.friendlier_id || asset.id}")
          return
        end

        # we're gonna use the same kithe promotion_directives for :delete to
        # control how we do dzi deletion too.
        Kithe::TimingPromotionDirective.new(
            key: :delete,
            directives: asset.file_attacher.promotion_directives) do |directive|

          if directive.inline?
            asset.dzi_package.delete
          elsif directive.background?
            DeleteDziJob.perform_later(asset.dzi_manifest_file&.id, asset.dzi_manifest_file&.storage_key)
          end
        end
      else

        # file changed, need to delete an old dzi?
        old_file_data, new_file_data = asset.file_data_previous_change
        old_dzi_manifest_file_data, new_dzi_manifest_file_data = asset.dzi_manifest_file_data_previous_change


        if old_file_data.present? || old_dzi_manifest_file_data.present?
          if asset.dzi_manifest_file.blank?
            Rails.logger.warn("Altering file without a dzi_manifest_file listed, can't find/delete DZI: #{asset.friendlier_id || asset.id}")
            return
          end

          if (old_file_data && old_file_data["id"] != new_file_data["id"]) ||
             old_dzi_manifest_file_data && old_dzi_manifest_file_data != new_dzi_manifest_file_data

            DeleteDziJob.perform_later(
              asset.json_attributes_previously_was.dig("dzi_manifest_file_data", "id"),
              asset.json_attributes_previously_was.dig("dzi_manifest_file_data", "storage")
            )
          end
        end
      end
      #
    end
  end
end
