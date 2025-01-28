require 'webvtt'

class OralHistoryContent
  class OhmsXml

    # Can parse WebVTT content -- or at least the subset delivered by the OHMS
    # new-style 2025 OHMS transcript with <vtt_transcript> element in xml.
    # https://www.w3.org/TR/webvtt1/
    #
    # Uses the `webvtt` gem for initial parsing, but that gem is basic and
    # not very maintained, so we need some massaging and post-processing
    # to get what we need.
    #
    # For OHMS, the WebVTT `<v>` voice tag is crucial for labelling speakers.
    #
    # See an example mock OHMS XML with WebVTT at ./spec/test_support/ohms_xml/small-sample-vtt-ohms.xml
    class VttTranscript
      FullSanitizer = Rails::HTML5::FullSanitizer.new

      attr_reader :raw_webvtt_text

      # @param raw_webvtt_text [String] WebVTT text as included in an OHMS xml export
      def initialize(raw_webvtt_text)
        @raw_webvtt_text = raw_webvtt_text || ""
      end

      def cues
        @cues ||= begin
          # parser requires initial WEBVTT line, which OHMS omits
          src = raw_webvtt_text
          unless src.start_with?('WEBVTT')
            src = "WEBVTT\n" + src
          end

          # original gem is sometimes picking up empty cues, which is annoying
          Webvtt::File.new(src).cues.collect { |webvtt_cue| Cue.new(webvtt_cue) }
        end
      end

      # eg for indexing, actual human-readable indexable plain text after parsed and extracted webVTT
      def transcript_text
        @transcript_text ||= cues.collect { |c| c.paragraphs }.flatten.collect do |p|
          if p.speaker_name
            "#{strip_tags p.speaker_name}: #{strip_tags p.raw_html}"
          else
            strip_tags p.raw_html
          end
        end.join("\n\n")
      end

      def strip_tags(s)
        # for some reason sometimes br's in input, which can end up eating up whitespace
        # and jamming two words together on strip, so we replace first
        FullSanitizer.sanitize( s.gsub("<br>", "\n") )
      end

      # our cue wraps webvtt cue with further parsed escaped content
      #
      # Each queue has an array of 0 or more 'paragraphs', each paragraph
      # can include <b>, <i>, and <u> tags, but has other html stripped,
      # and is html safe.
      #
      # Each paragraph may have an option speaker voice name
      #
      # Actual OHMS content at present will only put that on the first one,
      # and always has it, but this is not required by the standard or this code
      class Cue
        delegate :identifier, :start, :end, :settings, :text, to: :@webvtt_cue

        def initialize(webvtt_cue)
          @webvtt_cue = webvtt_cue
        end

        # parse start str into number of seconds as float
        def start_sec_f
          @start_sec_f ||= begin
            start =~ /(\d+):(\d\d)(\.\d\d\d)?/
            ($1.to_i * 60) + $2.to_i + $3.to_f
          end
        end

        #  parase end str into number of seconds as float
        def end_sec_f
          @end_sec_f ||= begin
            self.end =~ /(\d+):(\d\d)(\.\d\d\d)?/
            ($1.to_i * 60) + $2.to_i + $3.to_f
          end
        end

        def paragraphs
          @paragraphs ||= begin
            # This tricky regex using both positive lookahead and negative lookahead
            # will split into voice tags, taking into account that some text might not
            # be in a voice tag, and that voice tag does not have to ber closed when it's the whole cue
            (text || -"").split(/(?=\<v[ .])|(?<=\<\/v>)/).collect do |voice_span|
              # <v some name> or <v.class1.class2 some name>, in some cases ended with </v>
              if voice_span.gsub!(/\A\<v(?:\.[\w.]+)?\ ([^>]+)>/, '')
                speaker_name = $1
              end

              # \R is any kind of linebreak
              voice_span.split(/\R/).collect do |paragraph_text|
                Paragraph.new(speaker_name: speaker_name, raw_html: paragraph_text)
              end
            end.flatten
          end
        end
      end

      class Paragraph
        Scrubber = Rails::Html::PermitScrubber.new.tap do |scrubber|
          scrubber.tags = ['i', 'b', 'u']
        end

        attr_reader :speaker_name, :safe_html, :raw_html

        def initialize(speaker_name:, raw_html:)
          @raw_html = raw_html
          @speaker_name = speaker_name

          html_fragment = Loofah.fragment(raw_html)
          html_fragment.scrub!(Scrubber)

          @safe_html = html_fragment.to_s.strip.html_safe
        end
      end

    end


  end
end
