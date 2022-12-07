module OralHistory
  # Content of the "Downloads" tab for Oral History pages.
  class DownloadsListComponent < ApplicationComponent
    delegate :format_ohms_timestamp, :can_see_unpublished_records?, to: :helpers

    # our combined_audio_derivatives helper methods
    delegate :m4a_audio_url, :derivatives_up_to_date?, :m4a_audio_download_url,
      :m4a_audio_download_filename, :display_m4a_audio_size,
      to: :combined_audio_derivatives, prefix: "combined"

    attr_reader :decorator, :work, :combined_audio_derivatives

    # TODO decorator is a WIP on the path to a refactor
    def initialize(work:, decorator:)
      @work = work
      @decorator = decorator

      # some helper methods for working with our derived combined audio file(s)
      @combined_audio_derivatives = CombinedAudioDerivatives.new(work)
    end

    # Cache the total list of published members, in other methods we'll search
    # through this in-memory to get members for various spots on the page.
    def all_members
      @all_members ||= begin
        members = work.members.includes(:leaf_representative)
        unless can_see_unpublished_records?
           members = members.where(published: true)
        end
        members.order(:position).to_a
      end
    end

    def file_list_members
      @file_list_members ||= all_members.select do |m|
         !m.leaf_representative&.content_type&.start_with?("audio/") && # exclude audio
         !m.role_portrait?  # exclude portrait role
       end
    end

    def audio_members
      @audio_members ||= all_members.select { |m| m.leaf_representative&.content_type&.start_with?("audio/") }
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
