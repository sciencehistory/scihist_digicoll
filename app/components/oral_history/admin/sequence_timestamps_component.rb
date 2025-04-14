module OralHistory
  module Admin
    class SequenceTimestampsComponent < ApplicationComponent
      attr_reader :work

      delegate :cannot?, to: :helpers

      def initialize(work:)
        @work = work
      end


      # These methods copied from combined audio derivatives component, sorry not DRY
      def combined_audio_fingerprint
        return nil unless work.is_oral_history?
        work.oral_history_content&.combined_audio_fingerprint
      end

      def current_required_fingerprint
        @current_required_fingerprint ||= CombinedAudioDerivativeCreator.new(work).fingerprint
      end

      def has_good_combined_audio?
        work&.oral_history_content&.combined_audio_m4a_data.present? &&
        (current_required_fingerprint == combined_audio_fingerprint)
      end

    end
  end
end
