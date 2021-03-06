# Displays the "1 - 10 of 123" message.
#
# Similar to kaminari's #page_entries_info, I forget why we didn't just use that, maybe
# we wanted somewhat different functionality that we didn't know how to theme.
#
# https://github.com/kaminari/kaminari/blob/master/README.md#the-page_entries_info-helper-method
#
# Pass in a kaminari-paginated array.
class PageEntriesInfoDisplay < ViewModel
  def display
    return "" unless should_display?

    content_tag("p") do
      "#{model.offset_value + 1} - #{model.offset_value + model.count} of #{model.total_count}"
    end
  end

  protected

  def should_display?
    model.total_count > 0
  end

end
