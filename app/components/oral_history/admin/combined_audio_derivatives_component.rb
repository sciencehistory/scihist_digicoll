module OralHistory
  module Admin

    # Shows Admin UI related to the combined audio derivatives of an
    # oral history work on the work admin page (on the Oral History tab).
    #
    class CombinedAudioDerivativesComponent < ApplicationComponent
      # delegate to WORK for legacy reasons
      delegate :genre, :title, :additional_title, :parent, :source, :date_of_work, :published?,
        to: :work

      attr_reader :work

      def initialize(work:)
        @work = work
      end

      def work_available_members?
        @work_published_audio_members_count ||= CombinedAudioDerivativeCreator.new(work).available_members?
      end

      def work_available_members_count
        @work_available_members_count ||= CombinedAudioDerivativeCreator.new(work).available_members_count
      end

      def combined_m4a_audio
        return nil unless work.is_oral_history?
        return nil unless work_available_members?
        oh_content = work.oral_history_content!
        oh_content.combined_audio_m4a&.url(public:true)
      end

      def combined_audio_fingerprint
        return nil unless work.is_oral_history?
        work.oral_history_content!.combined_audio_fingerprint
      end

      def current_required_fingerprint
        @current_required_fingerprint ||= CombinedAudioDerivativeCreator.new(work).fingerprint
      end

      def derivatives_up_to_date?
        current_required_fingerprint == combined_audio_fingerprint
      end

      def job_status_time
        work&.oral_history_content&.combined_audio_derivatives_job_status_changed_at
      end

      def time_since_job_status_change
        "#{ distance_of_time_in_words(job_status_time, Time.now) } ago"
      end

      def show_in_progress_status?
        work&.oral_history_content&.queued?  ||
          work&.oral_history_content&.started? ||
          work&.oral_history_content&.failed?
      end
      # Whether the derivatives were recently recreated.
      def job_status_recently_changed?
        return Time.now.to_i - job_status_time.to_i  < 60*60*24
      end


    end
  end
end
