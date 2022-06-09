# To conduct an audit, run OrphanAuditor.new.perform!
# This will audit all derivatives, store it in DB, and remove any but the currently stored report in DB.
class OrphanAuditor
  attr_reader :originals, :public_derivatives, :restricted_derivatives, :dzi

  def check_all
    @tasks = {}
    @tasks[:originals] = OrphanS3Originals.new(show_progress_bar: false )
    @tasks[:public_derivatives] = OrphanS3Derivatives.new(show_progress_bar: false )
    @tasks[:restricted_derivatives] = OrphanS3RestrictedDerivatives.new(show_progress_bar: false )
    @tasks[:video_derivatives] = OrphanS3VideoDerivatives.new(show_progress_bar: false )
    @tasks[:dzi] = OrphanS3Dzi.new(show_progress_bar: false )
    @tasks.values.each &:report_orphans
    return !orphans?
  end

  def orphans?
    @tasks.values.any?{ |a| a && a.orphans_found > 0 }
  end

  def store_audit_results
    results = {
      orphaned_originals_count:  @tasks[:originals]&.orphans_found,
      orphaned_originals_sample: @tasks[:originals]&.sample,
      orphaned_public_derivatives_count:  @tasks[:public_derivatives]&.orphans_found,
      orphaned_public_derivatives_sample: @tasks[:public_derivatives]&.sample,
      orphaned_restricted_derivatives_count:  @tasks[:restricted_derivatives]&.orphans_found,
      orphaned_restricted_derivatives_sample: @tasks[:restricted_derivatives]&.sample,
      orphaned_video_derivatives_count:  @tasks[:video_derivatives]&.orphans_found,
      orphaned_video_derivatives_sample: @tasks[:video_derivatives]&.sample,
      orphaned_dzi_count:  @tasks[:dzi]&.orphans_found,
      orphaned_dzi_sample: @tasks[:dzi]&.sample,
    }
    results.each { |k, v| log_into_report( { k => v } ) }
  end

  def notify_if_failed
    if orphans?
      Honeybadger.notify("Orphaned items found. See report at #{File.join(ScihistDigicoll::Env.lookup(:app_url_base) || "", "/admin/orphan_report")}")
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
    @report ||= Admin::OrphanReport.create!
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
    Admin::OrphanReport.where.not(id: report.id).destroy_all
  end

end
