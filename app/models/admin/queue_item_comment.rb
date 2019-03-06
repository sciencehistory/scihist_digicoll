# A comment attached to a particular Admin::DigitizationQueueItem
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
  belongs_to :digitization_queue_item
end
