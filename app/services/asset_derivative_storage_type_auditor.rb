# An asset can have a derivative_storage_type of `public` or `restricted`. This
# class can check all Assets to:
#
# 1) ensure the derivatives are registered as stored in appropriate location
# for the derivative_storage-type
#
# 2) ensure no assets marked public have restricted derivative_storage_type, becuase
# that won't work well (if it uses presigned s3 urls for everything, it'll be far too
# slow
#
# 3) Notifies of any non-compliant Assets found, and records the result of the audit in ... TBD
#
#
#      auditor = AssetDerivativeStorageTypeAuditor.new
#      auditor.audit_all
#      auditor.incorrect_storage-lcoations
#         #=> array of Asset with registered mismatched storage locations
#      auditor.incorrectly_published
#         #=> array of Assets `published` with `derivative_storage_type == "restricted"` which should not be
#
#      auditor.failed_assets? #=> incorrect_storage-lcoations
#
# Or to just audit and record and store/notify in default ways:
#
#      AssetDerivativeStorageTypeAuditor.new.perform!
#
#
# We hypothetically could have postgres do some of these checks directly using pg json functions,
# but it's confusing SQL to get right, less flexible, and doing it the 'slow' way can still check
# all of our assets in a couple minutes, fine for a bg task.
class AssetDerivativeStorageTypeAuditor
  attr_reader :incorrect_storage_locations, :incorrectly_published

  HOW_MANY_DAYS_TO_KEEP_REPORTS = 60

  def check_all
    reset

    Asset.find_each do |asset|
      if !asset.derivatives_in_correct_storage_location?
        incorrect_storage_locations << asset
      end

      if asset.derivative_storage_type == "restricted" && asset.published?
        incorrectly_published << asset
      end
    end

    return !failed_assets?
  end

  def failed_assets?
    incorrect_storage_locations.present? || incorrectly_published.present?
  end

  def store_audit_results
    return unless failed_assets?

    if incorrect_storage_locations.present?
      log_into_report({ incorrect_storage_locations_count: incorrect_storage_locations.count })
      log_into_report({
        incorrect_storage_locations_sample:
          incorrect_storage_locations[0..10].
          collect(&:friendlier_id).
          join(",")
        })
    end

    if incorrectly_published.present?
      log_into_report({ incorrectly_published_count: incorrectly_published.count })
      log_into_report({
        incorrectly_published_sample:
          incorrectly_published[0..10].
          collect(&:friendlier_id).
          join(",")
        })
    end
  end

  def notify_if_failed
    if failed_assets?
      Honeybadger.notify("Assets with unexpected derivative_storage_type state found",
        context: {
          incorrect_storage_locations: incorrect_storage_locations.collect(&:friendlier_id).join(","),
          incorrectly_published: incorrectly_published.collect(&:friendlier_id).join(",")
        },
        tags: "derivative_storage_type"
      )

      DerivativeStorageTypeAuditMailer.
        with(asset_derivative_storage_type_auditor: self).
        audit_failure_email
        .deliver_now
    end
  end

  # Checks, records, and notifies of failures
  def perform!
    log_start
    check_all
    store_audit_results
    notify_if_failed
    delete_stale_reports
    log_end
  end

  private

  # Get or create the report
  def report
    @report ||= Admin::AssetDerivativeStorageTypeReport.create!
  end

  def log_start
    log_into_report({ start_time: Time.now.to_s })
  end

  def log_end
    log_into_report({ end_time:   Time.now.to_s })
  end

  def log_into_report(data)
    report.data_for_report.update(data)
    report.save!
  end

  def delete_stale_reports
    cutoff = HOW_MANY_DAYS_TO_KEEP_REPORTS.days.ago
    Admin::AssetDerivativeStorageTypeReport.
      where("created_at < ?", cutoff).destroy_all
  end

  def reset
    @incorrect_storage_locations = []
    @incorrectly_published = []
  end


end
