# Meant only for temporary use for bulk reclamation, adding exiftool results
# to existing assets on roll out of feature.
#
# Under normal use exiftool is done synchronously before promotion.
class AddExiftoolResultJob < ApplicationJob
  def perform(asset)
    asset.store_exiftool
    asset.save!
  end
end
