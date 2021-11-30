require "active_support/concern"
# Asset, Work and Collection all record
# their publication date by including this module.
module RecordPublishedAt
  extend ActiveSupport::Concern
  included do
    before_validation :set_published_at
    private
    def set_published_at
      self.published_at = DateTime.now if published? && published_changed?
    end
  end
end