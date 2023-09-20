# frozen_string_literal: true

class WorkDownloadLinksComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end
end
