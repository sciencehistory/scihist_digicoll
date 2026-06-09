# frozen_string_literal: true
#
# The standard SHI footer from main site
class ScihistFooterComponent < ApplicationComponent

  def logged_in_user?
    helpers.current_user
  end
end
