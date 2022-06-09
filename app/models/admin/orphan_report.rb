# A report of the most recent check for orphaned files.
#
# All the data is currently in a jsonb column `data_for_report`
class Admin::OrphanReport < ApplicationRecord

  def start_time
    data_for_report['start_time']&.to_datetime
  end

  def end_time
    data_for_report['end_time']&.to_datetime
  end

  def orphaned_originals_count
    data_for_report['orphaned_originals_count'].to_i
  end

  def orphaned_originals_sample
    data_for_report['orphaned_originals_sample'] || []
  end

  def orphaned_public_derivatives_count
    data_for_report['orphaned_public_derivatives_count'].to_i
  end

  def orphaned_public_derivatives_sample
    data_for_report['orphaned_public_derivatives_sample'] || []
  end

  def orphaned_restricted_derivatives_count
    data_for_report['orphaned_restricted_derivatives_count'].to_i
  end

  def orphaned_restricted_derivatives_sample
    data_for_report['orphaned_restricted_derivatives_sample'] || []
  end

  def orphaned_video_derivatives_count
    data_for_report['orphaned_video_derivatives_count'].to_i
  end

  def orphaned_video_derivatives_sample
    data_for_report['orphaned_video_derivatives_sample'] || []
  end

  def orphaned_dzi_count
    data_for_report['orphaned_dzi_count'].to_i
  end

  def orphaned_dzi_sample
    data_for_report['orphaned_dzi_sample'] || []
  end

end
