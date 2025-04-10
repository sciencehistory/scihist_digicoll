module OralHistory
  module Admin
    class SequenceTimestampsComponent < ApplicationComponent
      attr_reader :work

      delegate :cannot?, to: :helpers

      def initialize(work:)
        @work = work
      end
    end
  end
end
