module DownloadOptions
  # Download options for an asset of type "audio/", original and an mp3
  class AudioDownloadOptions < ViewModel
    alias_method :asset, :model

    def initialize(asset)
      super(asset)
    end

    # How many of this asset's parent's members are audio assets.
    def parent_audio_member_count
      @audio_members ||= begin
        members = asset.parent.members.with_representative_derivatives
        members = members.where(published: true) if current_user.nil?
        members.count { |m| m.leaf_representative&.content_type&.start_with?("audio/") }
      end
    end

    def options
      options = []

      # If this is the only audio asset,
      # let's also allow the user to download the "optimized mp3"
      # which also happens to be the "combined audio" for this work.
      #
      # If there are more than one audio assets, the audio_work_show_decorator
      # provides the user with way to download the combined audio in a separate section of the page.
      if parent_audio_member_count == 1
        if combined_mp3_deriv = asset.parent&.oral_history_content&.combined_audio_mp3
          options << DownloadOption.with_formatted_subhead("Optimized MP3",
            url: combined_mp3_deriv&.url(public:true),
            analyticsAction: "download_optimized_mp3",
            size: combined_mp3_deriv.size
          )
        end
      end

      # We don't use content_type in derivative option subheads,
      # cause it's in the main label. But do use it for original.

      if asset.stored?
        options << DownloadOption.with_formatted_subhead("Original file",
          url: download_path(asset),
          analyticsAction: "download_original",
          content_type: asset.content_type,
          size: asset.size
        )
      end

      return options
    end

  end
end
