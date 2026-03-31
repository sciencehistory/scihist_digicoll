require 'webvtt'

class OralHistoryContent
  class OhmsXml

    # Can parse WebVTT content -- or at least the subset delivered by the OHMS
    # new-style 2025 OHMS transcript with <vtt_transcript> element in xml.
    # https://www.w3.org/TR/webvtt1/
    #
    # Also handles some OHMS quirks, strips and formats OHMS-style citation
    # footnotes, etc.  This really is OHMS-speciifc in the end -- although
    # should be okay to use basic features for generic WebVTT?  We do so for
    # whisper ASR WebVTT too.
    #
    # Uses the `webvtt` gem for initial parsing, but that gem is basic and
    # not very maintained, so we need some massaging and post-processing
    # to get what we need.
    #
    # For OHMS, the WebVTT `<v>` voice tag is crucial for labelling speakers.
    #
    # See an example mock OHMS XML with WebVTT at ./spec/test_support/ohms_xml/small-sample-vtt-ohms.xml
    class VttTranscript
      attr_reader :raw_webvtt_text, :parsed_webvtt

      # @param raw_webvtt_text [String] WebVTT text as included in an OHMS xml export
      #
      # @param auto_correct_format [Boolean] default true. Add preface and suffix
      #   material if needed to make valid WebVTT.  Needed for some OHMS source.
      def initialize(raw_webvtt_text = "", auto_correct_format: true)
        # WebVTT must be in UTF-8, and vtt gem does not well if they aren't, but
        # file uplaods etc from Rails come in in Binary
        if raw_webvtt_text.encoding == Encoding::BINARY
          raw_webvtt_text.force_encoding("UTF-8")
        elsif raw_webvtt_text.encoding == Encoding::UTF_8
          raw_webvtt_text.encode("UTF-8")
        end

        if auto_correct_format
          # parser requires initial WEBVTT line, which OHMS omits
          unless raw_webvtt_text.start_with?('WEBVTT')
            raw_webvtt_text = "WEBVTT\n" + raw_webvtt_text
          end

          # and OHMS also often omits final empty line also required, adding an
          # extra doesn't hurt
          raw_webvtt_text = raw_webvtt_text + "\n"
        end

        @raw_webvtt_text = raw_webvtt_text
        @parsed_webvtt = WebVTT.from_blob(raw_webvtt_text)
      end

      def cues
        @cues ||= begin
          paragraph_index = 1
          parsed_webvtt.cues.collect do |webvtt_cue|
            Cue.new(webvtt_cue, start_paragraph_index: paragraph_index).tap do |cue|
              # keep our running paragraph count accurate
              paragraph_index += cue.paragraphs.count
            end
          end.tap do |cues|
            # fill in assumed_speaker_name if needed
            cues.collect(&:paragraphs).flatten.each_cons(2) do |first_p, second_p|
              if second_p.speaker_name.nil?
                second_p.assumed_speaker_name = (first_p.speaker_name || first_p.assumed_speaker_name)
              end
            end
          end
        end
      end

      # delivers extracted and indexed footnotes from OHMS WebVTT
      # using OHMS own custom format standards for such.
      #
      # Warning: Text is NOT sanitized!
      #
      # @returns a hash where index are OHMS footnote numbers/indicators
      def footnotes
        @footnotes ||= begin
          by_ref = {}

          raw_webvtt_text =~ /ANNOTATIONS BEGIN(.*)ANNOTATIONS END/m
          Nokogiri::XML.fragment($1 || "").xpath("annotation").each do |node|
            next unless node['ref'].present?

            by_ref[node['ref']] = node.inner_html
          end

          by_ref
        end
      end

      # scrubbed, ordered, html_safe values for printing footnotes at bottom
      def safe_footnote_values
        safe_footnote_values ||= footnote_array
      end

      def paragraphs
        @paragraphs ||= cues.collect(&:paragraphs).flatten
      end

      # eg for indexing, actual human-readable indexable plain text after parsed and extracted webVTT
      def transcript_text
        @transcript_text ||= paragraphs.collect(&:text_with_forced_speaker_label).join("\n\n")
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

        # 1-based index that we start at, so we can number our paragraphs
        # as we parse em.
        attr_reader :start_paragraph_index

        def initialize(webvtt_cue, start_paragraph_index:)
          @webvtt_cue = webvtt_cue
          @start_paragraph_index = start_paragraph_index
        end

        def start_sec_f
          self.start.to_f
        end

        def end_sec_f
          self.end.to_f
        end

        # split text inside a cue into paragraphs.
        #
        # Paragraphs are split on newlines (WebVTT standard) -- also on <br><br> (two+ in a row br tag),
        # which OHMS at least sometimes does.
        #
        # A change in WebVTT "voice" (speaker) will also result in a paragraph split, which
        # isn't quite right, but works out fine for how OHMS does things.
        def paragraphs
          paragraph_index = start_paragraph_index
          @paragraphs ||= begin
            # This tricky regex using both positive lookahead and negative lookahead
            # will split into voice tags, taking into account that some text might not
            # be in a voice tag, and that voice tag does not have to ber closed when it's the whole cue
            (text || -"").split(/(?=\<v[ .])|(?:\<\/v>)/).collect do |voice_span|
              # <v some name> or <v.class1.class2 some name>, in some cases ended with </v>
              if voice_span.gsub!(/\A\<v(?:\.[\w.]+)?\ ([^>]+)>/, '')
                speaker_name = $1
              end

              # \R is any kind of linebreak
              # Things coming from OHMS can separate paragraphs by `<br><br>`, annoyingly:
              # Split paragraphs on two more consecutive <br>
              voice_span.split(/\R|(?:\<br\>){2,}/).collect do |paragraph_text|
                paragraph_text.gsub!("</v>", "") # remove stray ending tags

                # we'll just use cue_index as paragraph index, a cue should be only one paragraph in OHMS
                OralHistoryContent::Paragraph.new(
                  speaker_name: speaker_name,
                  ohms_vtt_html: paragraph_text,
                  included_timestamps: [start_sec_f],
                  paragraph_index: paragraph_index
                ).tap { paragraph_index += 1 }
              end
            end.flatten
          end
        end
      end
    end
  end
end
