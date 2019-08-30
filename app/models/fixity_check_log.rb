class FixityCheckLog < ApplicationRecord
  belongs_to :asset
  validates_presence_of :asset

  # FixityCheckLog.check_asset(some_asset)
  def self.check(asset)
    raise ArgumentError.new("Please pass in an Asset.") unless asset.is_a? Asset
    self.new(asset: asset).run_check
  end

  def self.logs_for(asset, checked_uri)
    FixityCheckLog.where(asset: asset, checked_uri: checked_uri).order('created_at desc, id desc')
  end

  def failed?
    !passed?
  end

  def passed?
    passed
  end

  def run_check
    return nil if asset.nil?
    return nil unless asset.file.exists?
    self.checked_uri=  asset.file.url
    self.actual_result = actual_checksum
    self.expected_result = expected_checksum
    self.passed=(expected_result == actual_result)
    save!
  end

  private

  def expected_checksum
    asset.file.sha512
  end

  def actual_checksum
    sha_512 = nil
    asset.file.open(rewindable: false) do | io_object |
      sha_512 = Shrine::Plugins::Signature::SignatureCalculator.
        new(:sha512, format: :hex).
        call(io_object)
    end
    sha_512
  end
end
