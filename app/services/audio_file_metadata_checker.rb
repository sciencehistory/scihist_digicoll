class AudioFileMetadataChecker

  # Checks if an audio file is empty or otherwise unplayable.
  attr_reader :file
  
  # @param asset [Asset] an audio asset. We assume it's an audio asset - no checks performed here.
  def initialize(file)
    @file = file
  end

  # Returns an array of errors
  def file_errors
    return ["empty file"] if @file.size == 0
    errors = []
    metadata =  @file.metadata
    if metadata['duration_seconds'].nil?  || metadata['duration_seconds'] == 0
      errors << "audio duration is unavailable or zero" 
    end
    if metadata['bitrate'].nil? || metadata['audio_sample_rate'].nil?
      errors << "audio bitrate or sample rate is unavailable"
    end
    errors
  end
end
