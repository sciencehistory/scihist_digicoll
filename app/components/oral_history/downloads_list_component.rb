module OralHistory
  # Content of the "Downloads" tab for Oral History pages.
  class DownloadsListComponent < ApplicationComponent
    delegate :format_ohms_timestamp, :can_see_unpublished_records?, to: :helpers

    # our combined_audio_derivatives helper methods
    delegate :m4a_audio_url, :derivatives_up_to_date?, :m4a_audio_download_url,
      :m4a_audio_download_filename, :display_m4a_audio_size,
      to: :combined_audio_derivatives, prefix: "combined"

    attr_reader :work, :members_list, :combined_audio_derivatives

    # @param members_list [Array<Kithe::Model>] members the viewer can see, that we will prepare the downloads list from
    def initialize(work:, members_list:)
      @work = work
      @members_list = members_list

      # some helper methods for working with our derived combined audio file(s)
      @combined_audio_derivatives = CombinedAudioDerivatives.new(work)
    end

    def file_list_members
      @file_list_members ||= members_list.select do |m|
         !m.leaf_representative&.content_type&.start_with?("audio/") && # exclude audio
         !m.try(:role_portrait?)  # exclude portrait role
       end
    end

    def audio_members
      @audio_members ||= members_list.select { |m| m.asset? && m.leaf_representative&.content_type&.start_with?("audio/") }
    end

    # An array of start times for each audio member.
    # The key is the member uuid (NOT the friendlier id)
    # The value is the offset in seconds into the combined audio.
    # The first value in the array, if there is one,
    # should ALWAYS be zero.
    def start_times
      @start_times ||= begin
        metadata = work&.oral_history_content&.combined_audio_component_metadata
        metadata ? metadata['start_times'].to_h : {}
      end
    end

    # The start time or audio offset for a particular audio asset,
    # relative to the entire oral history interview (the work as a whole).
    # We're rounding to the nearest tenth of a second; easier to read.
    # Returns nil if there is no start time for this asset, or for any assets.
    def start_time_for(audio_asset)
      start_times[audio_asset.id]
    end
  end
end
