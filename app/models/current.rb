# ActiveSupport::CurrentAttributes is used to store global values related
# to a request, when it's just not feasible to pass them down.
#
# We use them to store current_user, mainly for setting on `created_by`
#
# https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html
#
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
