# Logs a report of an audit that checks whether all assets have their derivatives stored
# in the correct buckets.

class Admin::AssetDerivativeStorageTypeReport < ApplicationRecord
  def incorrectly_published_sample_array
    return [] if data_for_report['incorrectly_published_sample'].nil?
    data_for_report['incorrectly_published_sample'].split(",")
  end

  def incorrect_storage_locations_sample_array
    return [] if data_for_report['incorrect_storage_locations_sample'].nil?
    data_for_report['incorrect_storage_locations_sample'].split(",")
  end

end

