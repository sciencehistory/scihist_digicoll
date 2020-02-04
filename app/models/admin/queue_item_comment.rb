# A comment attached to a particular Admin::DigitizationQueueItem
# or Admin::RAndRItem.
# They are displayed kind of "facebook timeline"-style
#
# Text is in #text attribute.
#
# There is a boolean db column "system_action", which can be set to true
# to mean the text is some action text, not actually a user-entered text.
# We use this to record status changes (maybe more later?) in the timeline,
# cause why not. We don't worry about i18n for now though, we still just
# stick the user-displayable text in #text.
class Admin::QueueItemComment < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :digitization_queue_item, optional:true
  belongs_to :r_and_r_item, optional:true

  # A comment must be EITHER on an r_and_r_item,
  # XOR on a digitization_queue_item
  # (but can't and shouldn't be on both).
  validates :digitization_queue_item_id, presence: true, unless: :r_and_r_item_id
  validates :r_and_r_item_id, presence: true, unless: :digitization_queue_item_id
end
