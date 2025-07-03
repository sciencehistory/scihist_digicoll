# Use OpenAI audio transcribe API with whisper to transcribe.
#
# Will convert audio to a low-bitrate Opus Ogg for most efficient use with OpenAI
# API, under size limits.
#
# Can be used at several levels of abstraction, at the highest and most useful:
#
#    OpenaiAudioTranscribe.new.get_and_store_vtt_for_asset(audio_or_video_asset)
#    # => will extract and store in expected shrine derivative location
#
#    OpenaiAudioTranscribe.new.get_vtt_for_asset(audio_or_video_asset)
#    # => will extract and return webvtt as string
#
#    OpenaiAudioTranscribe.new.get_vtt(audio_file_io_obj)
#    # => process audio file with OpenAI api, return webvtt as string.
#
class OpenaiAudioTranscribe
  class Error < StandardError ; end

  REQUEST_TIMEOUT = 360 # seconds. default may be 120. In some cases not long enough?
  MODEL = "whisper-1"

  # some known hallucinations that very unlikely to be correct in our corpus, we
  # will just remove them.
  #
  # https://arxiv.org/html/2501.11378v1
  # https://github.com/DSP-AGH/ICASSP2025_Whisper_Hallucination
  REMOVE_TEXT = [
    # \p{Zs} is unicode separator space (not newline)
    /\p{Zs}*(© )?transcript Emily Beynon/
  ]

  attr_reader :use_prompt, :create_audio_derivative_if_needed

  def initialize(use_prompt: true, create_audio_derivative_if_needed: false)
    @use_prompt = !!use_prompt
    @create_audio_derivative_if_needed = !!create_audio_derivative_if_needed
  end

  # process audio from Asset with OpenAI whsiper, and store the transcript in
  # Asset derivatives, writing over anything else we had.
  def get_and_store_vtt_for_asset(asset)
    # If it's english and only english, give whisper a language code to
    # help it get started quicker. Otherwise let it figure it out for itself,
    # we don't have enough examples of this yet to spend time on it. If you give
    # a lang, can only give ONE.
    lang_code = asset.parent&.language == ["English"] ? "en" : nil

    webvtt = get_vtt_for_asset(asset, lang_code: lang_code)

    tech_provenance_metadata = {
      "api" => "OpenAI transcribe",
      "model" => MODEL,
      "language" => (lang_code if lang_code),
      "prompt" => (whisper_prompt(asset) if use_prompt)
    }.compact

    asset.file_attacher.add_persisted_derivatives(
        {Asset::ASR_WEBVTT_DERIVATIVE_KEY => StringIO.new(webvtt)},
        add_metadata:  { Asset::ASR_WEBVTT_DERIVATIVE_KEY =>
          {
            "asr_engine" => tech_provenance_metadata
          }
        }
    )
  end

  # Given an Asset with audio or video, extract audio as lowfi
  # Opus OGG, and contact OpenAI API to get a webvtt transcript
  def get_vtt_for_asset(asset, lang_code: nil)
    unless asset.content_type.start_with?("audio/") || asset.content_type.start_with?("video/")
      raise ArgumentError.new("Can only extract transcript from audio or video")
    end

    if asset.file_derivatives[AssetUploader::LOFI_OPUS_AUDIO_DERIV_KEY].blank? && create_audio_derivative_if_needed
      asset.create_derivatives(only: AssetUploader::LOFI_OPUS_AUDIO_DERIV_KEY)
    elsif asset.file_derivatives[AssetUploader::LOFI_OPUS_AUDIO_DERIV_KEY].blank?
      raise ArgumentError.new("asset #{asset&.friendlier_id} does not have a #{AssetUploader::LOFI_OPUS_AUDIO_DERIV_KEY.inspect} derivative. Either needs to exist, or pass in `create_audio_derivative_if_needed:true`")
    end

    # Would be nice to pass the IO object directly instead of having to make a temporary
    # download to our disk first, but ruby's lack of clear API for non-File IO leaves things
    # incompatible. At least the FIRST problem is:
    #
    # * https://github.com/socketry/multipart-post/issues/110
    # * https://github.com/janko/down/issues/99
    asset.file_derivatives[AssetUploader::LOFI_OPUS_AUDIO_DERIV_KEY].download do |opus_file|
      return get_vtt(opus_file, lang_code: lang_code, whisper_prompt: (whisper_prompt(asset) if use_prompt))
    end
  #ensure
    #opus_file.close if opus_file
  end

  # Given a File or Tempfile, contact OpenAI API and return transcribed WebVTT
  #
  # @param audio_file [Tempfile,File] pointing to an audio file, needs to be under 25 meg or
  # you'll get an error from Whisper. May need to be an actual File with #path for
  # the openai ruby client, even though it's not supposed to be required.
  #
  # @param lang_code [String] ISO-279 two-letter language code, optional, Whisper
  #   can only take one, the 'primary' one of the audio. Without it,  whisper will guess.
  #
  # @param whisper_prompt [Boolean] pass to openai whisper api as propmt if given.
  #    see eg https://cookbook.openai.com/examples/whisper_prompting_guide
  #
  # File path needs to actually end in a recognized suffix for OpenAI whisper:
  # ['flac', 'm4a', 'mp3', 'mp4', 'mpeg', 'mpga', 'oga', 'ogg', 'wav', 'webm']
  def get_vtt(audio_file, lang_code: nil, whisper_prompt:nil)
    parameters = {
      model: MODEL,
      file: audio_file,
      response_format: "vtt",
      language: lang_code, # Optional,
      prompt: whisper_prompt
    }.compact

    response = client.audio.transcribe(
      parameters: parameters
    )

    filter_removal_text(response)
  rescue Faraday::Error => e
    size_msg = if audio_file.respond_to?(:size) && audio_file.size
       "input file: #{ActiveSupport::NumberHelper.number_to_human_size(audio_file.size)}: "
    else
      ""
    end

    if e.response
      raise Error.new("OpenAI API error: #{size_msg}#{e.response[:status]}: #{e.response[:body]}")
    else
      raise Error.new("OpenAI API error: #{size_msg}#{e.class}: #{e.message}")
    end
  end

  def client
    @client ||= OpenAI::Client.new(
      access_token: ScihistDigicoll::Env.lookup("openai_api_key"),
      # Highly recommended in development, so you can see what errors OpenAI is returning. Not recommended in production because it could leak private data to your logs.
      log_errors: Rails.env.development?,
      request_timeout: REQUEST_TIMEOUT,
    )
  end

  # For guidance on openAI API whisper prompts, see:
  # https://cookbook.openai.com/examples/whisper_prompting_guide
  #
  # We're going to try using description to provide example words....
  def whisper_prompt(asset)
    # whisper prompt can only be max 224 "tokens", and otherwise it takes the LAST
    # part. We'd rather have the first part, so we'll try to truncate, using openai
    # rule of thumb that 100 tokens is 75 words, just limit to first 150 words.
    #
    # https://help.openai.com/en/articles/4936856-what-are-tokens-and-how-to-count-them
    asset.parent&.description&.truncate_words(150, omission: "")
  end

  # Remove text we've marked as likely hallucination...
  #
  # While it would be best to delete whole cue if it's now blank, we aren't doing
  # that for now, keeping it quick and easy.
  def filter_removal_text(webvtt_str)
    webvtt_str = webvtt_str.dup

    REMOVE_TEXT.each do |pattern|
      webvtt_str.gsub!(pattern, '')
    end

    return webvtt_str
  end
end
