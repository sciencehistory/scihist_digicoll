require 'prawn'
require 'rinku'

# Create PDF for trans[cription] or trans[lation]
#
# Uses `prawn` PDF generation gem, with `prawn-svg` and `prawn-html` extensions.
#
# We mostly create HTML first and then generate PDF from it -- this is useful
# because we have some existing routines for generating html we can re-use, but
# also just because formatting with HTML is a lot easier than with low-level
# prawn/PDF commands.
#
# While it might be more elegant to create HTML with .erb, perhaps via ViewComponent --
# wound up kind of fighting with that, because of Rails view_context etc weirdness.
# So we do it the hacky way by including Rails HTML helpers in, and building up
# the HTML with method calls. Works out okay for such relatively simple HTML.
#
class TransTextPdf
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::OutputSafetyHelper

  attr_reader :work, :mode

  # @param mode [Symbol] :translation or :transcription
  def initialize(work, mode:)
    @work = work
    @mode = mode

    unless @mode == :transcription || @mode == :english_translation
      raise ArgumentError.new("mode must be :translation or :transcription not `#{@mode}`")
    end
  end

  # @return [Prawn::Document] Can be saved to disk, or perhaps streamed directly
  #   to a client.
  #
  # @raise ActionController::RoutingError if not text is available
  def prawn_pdf
    unless text_page_objects.present?
      raise ActionController::RoutingError.new("No text available to compile for #{mode}")
    end

    Prawn::Document.new.tap do |pdf|
      font_base = Rails.root + "app/assets/fonts/liberation_serif"
      pdf.font_families.update(
        'LiberationSerif' => {
          normal: font_base + "LiberationSerif-Regular.ttf",
          italic: font_base + "LiberationSerif-Italic.ttf",
          bold: font_base + "LiberationSerif-Bold.ttf",
          bold_italic: font_base + "LiberationSerif-BoldItalic.ttf"
       }
     )

      # We add the header SVG in not via HTML, because prawn-html does not support SVGs!
      pdf.svg IO.read(Rails.root + "app/assets/images/Science_History_logo_dk_blue_rgb.svg"), width: 200

      pdf.move_down 15

      # Then the rest of our content as an HTML block via prawn-html
      PrawnHtml.append_html(pdf, content_html)
    end
  end

  # pretty kludgey html construction, but it works
  def content_html
    body = safe_join(
      [
        content_tag("h1", work.title),
        content_tag("div", intro_matter, class: "intro-matter"),
        content_tag("h2", mode.to_s.titlecase),
        pages_html
      ].compact
    )

    # to apply CSS that prawn-html will use we NEED to embed it in an HTML doc
    # like this, which we do the stupidest way, to choose a custom font, and
    # some appropriate sizing/spacing.
    <<~EOS.html_safe
      <html>
        <head>
          <style>
            #{style_css}
          </style>
        </head>
        <body>
          #{body}
        </body>
      </html>
    EOS
  end

  def intro_matter
    safe_join([
      citation_html,
      content_tag("p", "Courtesy of the Science History Institute, prepared #{localize(Time.now, format: :long)}"),
      (content_tag("p", additional_credit) if additional_credit),
    ])
  end


  def additional_credit
    unless defined?(@additional_credit)
      role = (mode == :transcription) ? "transcribed_by" : "translated_by"

      @additional_credit = work.additional_credit.find { |ac| ac.role == role }&.display_as
    end

    @additional_credit
  end

  # use our existing CitationDisplay component to create HTML citation, but
  # then turn http links into actual <a> links too with Rinku
  def citation_html
    # Rinku doens't preserve html_safety, so we need to call html_safe.
    # https://github.com/vmg/rinku/issues/94
    Rinku.auto_link(
      CitationDisplay.new(work).display,
      nil, nil, nil, Rinku::AUTOLINK_SHORT_DOMAINS
    ).html_safe
  end

  # combines text from multiple assets, properly HTML formatted. Our trans text
  # can have simple HTML formatting, which we want to safely include -- we
  # re-use DescriptionFormatter for formatting, including what html tags to allow.
  def pages_html
    text_page_objects.collect do |page|
      # we include page label headers if we have more than one page
      if text_page_objects.length > 1
        content_tag("h3", page.page_label)
      else
        "".html_safe
      end +

      DescriptionDisplayFormatter.new(page.text).format
    end
  end

  def text_page_objects
    # whether user is administrator or not, we don't include private pages for now.
    @text_page_objects ||= Work::TextPage.compile(work.ordered_viewable_members(current_user: nil), accessor: mode)
  end

  # some trying-to-keep-it-simple CSS, that will be converted to PDF by
  # prawn-html, which only supports very simple CSS.
  # https://github.com/blocknotes/prawn-html#supported-tags--attributes
  def style_css
    <<~EOS
      body {
        font-family: LiberationSerif;
        font-size: 22px;
      }
      h1 {
        font-size: 40px;
        line-height: 1;
      }
      h2 { font-size: 34px; }
      h3 { font-size: 28px; }
      h4 { font-size: 24px; }

      .intro-matter {
        margin-left: 120px;
        margin-bottom: 40px;
        margin-top: 40px;
      }

      p {
        /* don't know what 8px means, that's weird, but works for what we want */
        line-height: 8px;
      }
    EOS
  end
end
