module DigitizationQueueItemsHelper
  # just a hacky helper to show a dt/dd for a given Admin::DigitizationQueueItem field,
  # if present, we could be using presenters, or something else. This gets us started
  # with a basic show view.
  def queue_item_show_field(item, field, humanize_value: false, paragraphs: false)
    value = item.send(field)
    if value.present?
      if humanize_value
        value = value.humanize
      end
      if paragraphs
        value = simple_format(value)
      end

      content_tag("dt", field.to_s.titleize) +
        content_tag("dd", value)
    end
  end
end
