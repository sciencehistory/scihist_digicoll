# Displays the "1 - 10 of 123" message.
#
# Similar to kaminari's #page_entries_info, I forget why we didn't just use that, maybe
# we wanted somewhat different functionality that we didn't know how to theme.
#
# https://github.com/kaminari/kaminari/blob/master/README.md#the-page_entries_info-helper-method
#
# Pass in a kaminari-paginated array.
class PageEntriesInfoComponent < ApplicationComponent
  attr_reader :paginated_array

  def initialize(paginated_array)
    @paginated_array = paginated_array
  end

  def render?
    paginated_array.total_count > 0
  end

  def call
    content_tag("p") do
      "#{paginated_array.offset_value + 1} - #{paginated_array.offset_value + paginated_array.count} of #{paginated_array.total_count}"
    end
  end
end
