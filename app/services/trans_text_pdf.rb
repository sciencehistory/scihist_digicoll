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
  def prawn_pdf
    Prawn::Document.new.tap do |pdf|
      # We add the header SVG in not via HTML, because prawn-html does not support SVGs!
      pdf.svg IO.read(Rails.root + "app/assets/images/Science_History_logo_dk_blue_rgb.svg"), width: 200

      pdf.move_down 15

      # Then the rest of our content as an HTML block via prawn-html
      PrawnHtml.append_html(pdf, content_html)
    end
  end

  def content_html
    safe_join(
      [
        content_tag("h1", work.title),
        citation_html,
        content_tag("p", "Courtesy of the Science History Institute, prepared #{localize(Time.now, format: :long)}"),
        (content_tag("p", additional_credit) if additional_credit),
        content_tag("h2", mode.to_s.titlecase),
        pages_html
      ].compact
    )
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
    # whether user is administrator or not, we don't include private pages for now.
    pages = Work::TextPage.compile(work.ordered_viewable_members(current_user: nil), accessor: mode)

    pages.collect do |page|
      # we include page label headers if we have more than one page
      if pages.length > 1
        content_tag("h3", page.page_label)
      else
        "".html_safe
      end +

      DescriptionDisplayFormatter.new(page.text).format
    end
  end
end
