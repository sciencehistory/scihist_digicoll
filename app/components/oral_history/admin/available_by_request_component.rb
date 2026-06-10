module OralHistory
  module Admin
    # Component on Admin screens, UI for adjusting the available by request status
    # for Oral Histories.
    class AvailableByRequestComponent < ApplicationComponent
      attr_reader :work

      def initialize(work:)
        @work = work
      end

      def private_asset_members
        @private_asset_members ||= work.members.find_all { |m| m.kind_of?(Asset) && !m.published? }
      end
    end
  end
end
