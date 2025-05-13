# Use OpenAI audio transcribe API with whisper to transcribe
#
class OpenaiAudioTranscribe
  class Error < StandardError ; end

  def get_vtt_for_asset(asset)
    lofi_opus = FfmpegExtractOpusAudio.new.call(asset.file)

    get_vtt(lofi_opus)
  ensure
    lofi_opus.unlink if lofi_opus
  end

  # @param audio_file [File] pointing to an audio file, needs to be under 25 meg or
  # you'll get an error from Whisper. May need to be an actual File with #path for
  # the openai ruby client, even though it's not supposed to be required.
  #
  # @param lang_code [String] ISO-279 two-letter language code, optional, Whisper
  #   can only take one, the 'primary' one of the audio. Without it,  whisper will guess.
  #
  # File path needs to actually end in a recognized suffix for OpenAI whisper:
  # ['flac', 'm4a', 'mp3', 'mp4', 'mpeg', 'mpga', 'oga', 'ogg', 'wav', 'webm']
  def get_vtt(audio_file, lang_code: nil)
      response = client.audio.transcribe(
        parameters: {
          model: "whisper-1",
          file: audio_file,
          response_format: "vtt",
          language: lang_code, # Optional
        }
      )
  rescue Faraday::Error => e
    raise Error.new("OpenAI API error: #{e.response[:status]}: #{e.response[:body]}")
  end

  def client
    @client ||= OpenAI::Client.new(
      access_token: ScihistDigicoll::Env.lookup("openai_api_key"),
      # Highly recommended in development, so you can see what errors OpenAI is returning. Not recommended in production because it could leak private data to your logs.
      log_errors: Rails.env.development?
    )
  end

end
