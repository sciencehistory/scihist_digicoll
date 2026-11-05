module OralHistory
  module Admin
    class SequenceTimestampsComponent < ApplicationComponent
      attr_reader :work

      delegate :cannot?, to: :helpers

      def initialize(work:)
        @work = work
      end


      def has_good_combined_audio?
        !!work&.oral_history_content&.combined_audio_up_to_date?
      end

    end
  end
end
