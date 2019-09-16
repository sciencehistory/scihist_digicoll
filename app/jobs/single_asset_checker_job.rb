class SingleAssetCheckerJob < ApplicationJob
  def perform(asset)
    checker = FixityChecker.new(asset)
    checker.check
    checker.prune_checks
  end
end
