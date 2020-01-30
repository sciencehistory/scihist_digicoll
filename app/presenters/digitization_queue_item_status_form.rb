# Displays a little self-contained auto-submitting form for a DigitizationQueueItem. Uses rails-ujs,
# with customization in queue_status_submit.js.
#
# For admins, to let them see and change a queue item status without any clicks beyond the select menu,
# using AJAX, with progress spinner and error handling.
#
# Renders it's own form, NOT meant for use within an existing form!
#
#     <%= DigitizationQueueItemStatusForm.new(queue_item).display %>
#
class DigitizationQueueItemStatusForm < ViewModel
  valid_model_type_names 'Admin::DigitizationQueueItem', 'Admin::RAndRItem'

  def display
    render "/presenters/digitization_queue_item_status_form", model: model, view: self
  end
end
