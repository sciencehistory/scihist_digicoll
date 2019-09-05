
# This is the record of a fixity check.
# See also /app/services/fixity_checker.rb, which has most of the functionality
# relating to creating and pruning fixity checks.

class FixityCheck < ApplicationRecord
  belongs_to :asset
  validates_presence_of :asset

  # Returns in reverse chron order: first is most recent check.
  def self.checks_for(asset, checked_uri)
    FixityCheck.where(asset: asset, checked_uri: checked_uri).order('created_at desc, id desc')
  end

  def failed?
    !passed?
  end

  def passed?
    passed
  end

end