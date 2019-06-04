require 'rails_helper'

describe WorkProvenanceDisplay do

  let(:work_0) { FactoryBot.create(:work, provenance:  nil )}
  let(:work) { FactoryBot.create(:work, provenance:  "provenance metadata" )}

  it "returns an empty string if provenance is blank" do
    expect(WorkProvenanceDisplay.new(work_0).display). to eq ""
  end

  it "correctly splits the provenance (2)" do
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
        "<p>notes\n<br>NOTES:\n<br>notes\n<br>NOTES:\n<br>notes</p>"
      ],
      [ "provenance metadata",
        "<p>provenance metadata</p>",
        ""
      ],
      [ "July, 1913, sold by the artist to Franz Hauer (b. 1867 – d. 1914), Vienna [see note 1]. Probably about 1914/1915, acquired Oskar Reichel (b. 1869 - d. 1943), Vienna [see note 2]; February, 1939, transferred by Reichel to Otto Kallir (b. 1894 - d. 1978), Galerie St. Etienne, Paris and New York [see note 3]; 1945, sold by Galerie St. Etienne, New York, to the Nierendorf Gallery, New York; 1945, sold by Nierendorf to Silberman Galleries, New York; 1947/1948, probably sold by Silberman to Sarah Reed (Mrs. John) Blodgett, later Sarah Reed Platt (d. by 1972), Grand Rapids, Portland, Oregon and Santa Barbara; 1973, bequest of Sarah Reed Platt to the MFA. (Accession Date: April 11, 1973)\n\nNOTES:\n[1] Kokoschka wrote to Franz Hauer on July 21, 1913 outlining the terms of Hauer’s acquisition of the painting Lovers (“Liebespaar”) the following day. After Hauer’s death in 1914, the painting was listed in an inventory of his estate as the Dancing Nude Couple (“Akt Tanzender Paar”). Many thanks to Christian Bauer of the State Gallery of Lower Austria and Katharina Erling of the Kokoschka catalogue raisonné project for supplying this information.\n\n[2] Dr. Oskar Reichel was an admirer, collector, and patron of Kokoschka's work. Tobias G. Natter, Die Welt von Klimt, Schiele und Kokoschka: Sammler und Mäzene (Cologne, 2003), 254, suggests he acquired the painting around 1914/1915. It was first published as being in Dr. Reichel's collection by Paul Westheim in Das Kunstblatt 1 (1917), p. 319.\n\n[3] On February 1, 1939, Reichel transferred the painting--along with four other Kokoschka paintings--to the dealer Otto Kallir, who at that time ran the Galerie St. Etienne in Paris. Kallir exhibited it in Paris that spring and brought it to the United States later that year. After his arrival in the United States, he paid Reichel's two sons, who had already immigrated to North and South America, for the paintings. Kallir opened a branch of his Galerie St. Etienne in New York and exhibited this work often between 1940 and 1945.\n\nFor further information, please see \"Resolved Claims\" at <a href=\"http://www.mfa.org/collections/provenance/nazi-era-provenance-research\">",
        "<p>July, 1913, sold by the artist to Franz Hauer (b. 1867 – d. 1914), Vienna [see note 1]. Probably about 1914/1915, acquired Oskar Reichel (b. 1869 - d. 1943), Vienna [see note 2]; February, 1939, transferred by Reichel to Otto Kallir (b. 1894 - d. 1978), Galerie St. Etienne, Paris and New York [see note 3]; 1945, sold by Galerie St. Etienne, New York, to the Nierendorf Gallery, New York; 1945, sold by Nierendorf to Silberman Galleries, New York; 1947/1948, probably sold by Silberman to Sarah Reed (Mrs. John) Blodgett, later Sarah Reed Platt (d. by 1972), Grand Rapids, Portland, Oregon and Santa Barbara; 1973, bequest of Sarah Reed Platt to the MFA. (Accession Date: April 11, 1973)</p>",
        "<p>[1] Kokoschka wrote to Franz Hauer on July 21, 1913 outlining the terms of Hauer’s acquisition of the painting Lovers (“Liebespaar”) the following day. After Hauer’s death in 1914, the painting was listed in an inventory of his estate as the Dancing Nude Couple (“Akt Tanzender Paar”). Many thanks to Christian Bauer of the State Gallery of Lower Austria and Katharina Erling of the Kokoschka catalogue raisonné project for supplying this information.</p><p>[2] Dr. Oskar Reichel was an admirer, collector, and patron of Kokoschka's work. Tobias G. Natter, Die Welt von Klimt, Schiele und Kokoschka: Sammler und Mäzene (Cologne, 2003), 254, suggests he acquired the painting around 1914/1915. It was first published as being in Dr. Reichel's collection by Paul Westheim in Das Kunstblatt 1 (1917), p. 319.</p><p>[3] On February 1, 1939, Reichel transferred the painting--along with four other Kokoschka paintings--to the dealer Otto Kallir, who at that time ran the Galerie St. Etienne in Paris. Kallir exhibited it in Paris that spring and brought it to the United States later that year. After his arrival in the United States, he paid Reichel's two sons, who had already immigrated to North and South America, for the paintings. Kallir opened a branch of his Galerie St. Etienne in New York and exhibited this work often between 1940 and 1945.</p><p>For further information, please see \"Resolved Claims\" at <a href=\"http://www.mfa.org/collections/provenance/nazi-era-provenance-research\"></a></p>"
      ],
    ].each do |test_values|
      raw_value, expected_summary, expected_notes = test_values
      work.provenance = raw_value
      template_output = WorkProvenanceDisplay.new(work).display
      parsed_output = Nokogiri::HTML.fragment(template_output)
      summary = parsed_output.css('.provenance-summary')[0].
        children.map{ |x| x.serialize().strip }.join
      notes   = parsed_output.css('.provenance-notes')[0].
        children.map{ |x| x.serialize().strip }.join
      expect(summary).to eq expected_summary
      expect(notes).to eq   expected_notes
    end
  end
end
