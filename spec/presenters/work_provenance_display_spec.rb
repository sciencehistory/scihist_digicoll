require 'rails_helper'

describe WorkProvenanceDisplay do

  it "returns an empty string if provenance is blank" do
    expect(WorkProvenanceDisplay.new(nil).display). to eq ""
  end

  # Expected values don't have non-significant HTML newlines, so we can more easily
  # test against actual, stripping out newlines from actual.
  [
    [ "provenance metadata\n\nNOTES:\n\n notes",
      "<p>provenance metadata</p>",
      "<p>notes</p>"
    ],
    [ "provenance metadata\n\nNotes:\n\nnotes",
      "<p>provenance metadata</p>",
      "<p>notes</p>"
    ],
    [ "provenance metadata\r\n NOTES:\r\nnotes",
      "<p>provenance metadata</p>",
      "<p>notes</p>"
    ],
    [ "provenance metadata\r\n NOTES:\r\nnotes\r\nNOTES:\r\nnotes\r\nNOTES:\r\nnotes",
      "<p>provenance metadata</p>",
      "<p>notes<br>NOTES:<br>notes<br>NOTES:<br>notes</p>"
    ],
    [ "provenance metadata",
      "<p>provenance metadata</p>",
      ""
    ],
    [ "Marie-Thérèse Trinidad Brocheton, Comtesse de La Béraudière (1872-1958) [1]; (sale, Collection of the Countess de la Béraudière, American Art Association, Anderson Galleries, Jay Gould Mansion, New York, 1930, lot 20 (with \"Le Notaire\", not illustrated).\n\nWilliam Fox, acquired 1930; by descent to his widow, Mrs. William Fox. (Sale, Kende Galleries, New York, 1-2 December 1942, lot 58 [with \"Le Notaire,\" $320.00].)\n\nFisher Scientific, Pittsburgh, PA; Fisher Scientific International Inc., Hampton, NH (acquired by Chester G. Fisher), circa 1942-2000.\n\nThe Chemical Heritage Foundation, 2000 (from Fisher Scientific).\n\nNOTES:\n\n[1] Marie-Thérèse Trinidad Brocheton, Comtesse de La Béraudière (1872-1958) was a French salonniere and literary figure. Madame de La Béraudière was a friend of the famous novelist, Marcel Proust, and she was the mistress of the wealthy Henri Charles, Comte de Greffuhle (1845-1932). Madame de La Béraudière was the model for Proust's character Odette, the mistress of the Duc de Guermantes in his series of novels À la recherche du temps perdu (In Search of Lost Time).",
      "<p>Marie-Thérèse Trinidad Brocheton, Comtesse de La Béraudière (1872-1958) [1]; (sale, Collection of the Countess de la Béraudière, American Art Association, Anderson Galleries, Jay Gould Mansion, New York, 1930, lot 20 (with \"Le Notaire\", not illustrated).</p><p>William Fox, acquired 1930; by descent to his widow, Mrs. William Fox. (Sale, Kende Galleries, New York, 1-2 December 1942, lot 58 [with \"Le Notaire,\" $320.00].)</p><p>Fisher Scientific, Pittsburgh, PA; Fisher Scientific International Inc., Hampton, NH (acquired by Chester G. Fisher), circa 1942-2000.</p><p>The Chemical Heritage Foundation, 2000 (from Fisher Scientific).</p>",
      "<p>[1] Marie-Thérèse Trinidad Brocheton, Comtesse de La Béraudière (1872-1958) was a French salonniere and literary figure. Madame de La Béraudière was a friend of the famous novelist, Marcel Proust, and she was the mistress of the wealthy Henri Charles, Comte de Greffuhle (1845-1932). Madame de La Béraudière was the model for Proust's character Odette, the mistress of the Duc de Guermantes in his series of novels À la recherche du temps perdu (In Search of Lost Time).</p>"
    ],
  ].each do |raw_value, expected_summary, expected_notes|
    it "correctly splits provenance '#{raw_value[0..30].gsub(/[\n\r]/, ' ')}...'" do

      template_output = WorkProvenanceDisplay.new(raw_value).display
      parsed_output = Nokogiri::HTML.fragment(template_output)

      summary = parsed_output.css('.provenance-summary').inner_html.strip.gsub("\n", '')
      notes   = parsed_output.css('.provenance-notes').inner_html.strip.gsub("\n", '')

      expect(summary).to eq expected_summary
      expect(notes).to eq   expected_notes
    end
  end
end
