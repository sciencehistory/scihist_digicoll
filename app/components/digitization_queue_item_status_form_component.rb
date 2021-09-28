# Displays a little self-contained auto-submitting form for a DigitizationQueueItem. Uses rails-ujs,
# with customization in queue_status_submit.js.
#
# For admins, to let them see and change a queue item status without any clicks beyond the select menu,
# using AJAX, with progress spinner and error handling.
#
# Renders it's own form, NOT meant for use within an existing form!
#
#     <%= render DigitizationQueueItemStatusFormComponent.new(queue_item) %>
#
class DigitizationQueueItemStatusFormComponent < ApplicationComponent
  attr_reader :model

  def initialize(model)
    @model = model
  end
end
