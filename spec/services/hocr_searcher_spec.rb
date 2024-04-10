require "rails_helper"

describe HocrSearcher do
  # set height and width to match the faked HOCR
  let(:asset) { create(:asset_with_faked_file, :with_ocr, published: true, faked_width: 2767, faked_height: 3558) }
  let(:work) { create(:public_work, members: [ asset, create(:asset_with_faked_file) ])}

  it "produces matches" do
    searcher = HocrSearcher.new(work, query: "units")

    results = searcher.results_for_osd_viewer
    expect(results).to be_kind_of(Array)
    expect(results.length).to be 1

    result = results.first
    expect(result).to be_kind_of(Hash)
    expect(result["id"]).to eq asset.friendlier_id
    expect(result['text']).to be_kind_of(String)
    expect(result['text']).to match "<mark>units</mark>"
    expect(result['osd_rect']).to be_kind_of(Hash)

    # sanity check
    %w{left top height width}.each do |key|
      expect(result['osd_rect'][key]).to be_kind_of(Float)
      expect(result['osd_rect'][key]).not_to eq(Float::INFINITY)
      expect(result['osd_rect'][key]).to be < (asset.width * 4)
    end
  end

  describe "multi-word search" do
    let(:asset1) { create(:asset_with_faked_file, :with_ocr, published: true, faked_width: 2767, faked_height: 3558) }
    let(:asset2) { create(:asset_with_faked_file, hocr: HOCR_2_TXT, published: true, faked_width: 3348, faked_height: 4580) }
    let(:work) { create(:public_work, members: [ asset1, asset2 ])}

    it "finds both words, one on each page" do
      searcher = HocrSearcher.new(work, query: "ddt units")

      results = searcher.results_for_osd_viewer
      expect(results).to be_kind_of(Array)
      expect(results.length).to be 2
    end
  end

  describe "escaped quotes" do
    let(:asset) { create(:asset_with_faked_file, hocr: HOCR_2_TXT, published: true, faked_width: 3348, faked_height: 4580) }
    let(:work) { create(:public_work, members: [ asset ])}

    it "finds words with internal escaped quotes" do
      searcher = HocrSearcher.new(work, query: "single'quote")
      expect(searcher.results_for_osd_viewer).to be_present

      searcher = HocrSearcher.new(work, query: 'double"quote')
      expect(searcher.results_for_osd_viewer).to be_present
    end
  end

  # cheaper tests
  describe "#normalize_query" do
    it "ignores extra spaces" do
      expect(HocrSearcher.new(nil, query: "   one   two   ").query).to eq ["one", "two"]
    end

    it "leaves internal punctuation alone" do
      expect(HocrSearcher.new(nil, query: "isn't one-two").query).to eq ["isn't", "one-two"]
    end
  end

  # This needs to match what the viewer itself does, when we wrote this it does
  describe "with child work" do
    let(:parent_work) { create(:public_work, members: [work]) }

    it "includes single representative, with direct member id" do
      searcher = HocrSearcher.new(parent_work, query: "units")

      results = searcher.results_for_osd_viewer
      expect(results).to be_kind_of(Array)
      expect(results.length).to be 1

      expect(results.first["id"]).to eq work.friendlier_id
    end
  end

  describe "with unpublished member" do
    let(:asset) { create(:asset_with_faked_file, :with_ocr, published: false, faked_width: 2767, faked_height: 3558) }

    it "does not include unpublished asset" do
      searcher = HocrSearcher.new(work, query: "units")
      expect(searcher.results_for_osd_viewer).not_to include(an_object_satisfying { |h| h["id"] == asset.friendlier_id })
    end

    context "when including unpublished" do
      it "includes unpublished asset" do
        searcher = HocrSearcher.new(work, show_unpublished: true, query: "units")

        expect(searcher.results_for_osd_viewer).to include(an_object_satisfying { |h| h["id"] == asset.friendlier_id })
      end
    end
  end
end

HOCR_2_TXT = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title></title>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
  <meta name='ocr-system' content='tesseract 4.1.1' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word ocrp_wconf'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='image "/tmp/shrine20230901-142-epvi83.tif"; bbox 0 0 3348 4580; ppageno 0'>
   <div class='ocr_carea' id='block_1_1' title="bbox 968 1803 3003 2295">
    <p class='ocr_par' id='par_1_1' lang='eng' title="bbox 968 1803 3003 2295">
     <span class='ocr_line' id='line_1_1' title="bbox 973 1803 3003 1920; baseline 0.014 -40; x_size 56; x_descenders 15; x_ascenders 16">
      <span class='ocrx_word' id='word_1_1' title='bbox 973 1803 1070 1900; x_wconf 67'>Tre</span>
      <span class='ocrx_word' id='word_1_2' title='bbox 1118 1853 1241 1896; x_wconf 96'>great</span>
      <span class='ocrx_word' id='word_1_3' title='bbox 1261 1847 1568 1899; x_wconf 96'>expectations</span>
      <span class='ocrx_word' id='word_1_4' title='bbox 1589 1848 1690 1889; x_wconf 96'>held</span>
      <span class='ocrx_word' id='word_1_5' title='bbox 1711 1850 1778 1891; x_wconf 96'>for</span>
      <span class='ocrx_word' id='word_1_6' title='bbox 1803 1852 1935 1894; x_wconf 71'>DDT</span>
      <span class='ocrx_word' id='word_1_7' title='bbox 1945 1843 1996 1918; x_wconf 60'>_</span>
      <span class='ocrx_word' id='word_1_8' title='bbox 2044 1871 2127 1896; x_wconf 92'>one</span>
      <span class='ocrx_word' id='word_1_9' title='bbox 2152 1856 2200 1897; x_wconf 92'>of</span>
      <span class='ocrx_word' id='word_1_10' title='bbox 2220 1857 2297 1898; x_wconf 96'>the</span>
      <span class='ocrx_word' id='word_1_11' title='bbox 2321 1860 2552 1914; x_wconf 96'>country’s</span>
      <span class='ocrx_word' id='word_1_12' title='bbox 2577 1861 2739 1918; x_wconf 96'>largest</span>
      <span class='ocrx_word' id='word_1_13' title='bbox 2764 1867 3003 1920; x_wconf 96'>producers</span>
     </span>
     <span class='ocr_line' id='line_1_2' title="bbox 972 1909 3000 1997; baseline 0.016 -45; x_size 57; x_descenders 14; x_ascenders 19">
      <span class='ocrx_word' id='word_1_14' title='bbox 972 1909 1092 1951; x_wconf 75'>have</span>
      <span class='ocrx_word' id='word_1_15' title='bbox 1137 1911 1255 1952; x_wconf 89'>been</span>
      <span class='ocrx_word' id='word_1_16' title='bbox 1301 1914 1520 1957; x_wconf 0'>xealized.,</span>
      <span class='ocrx_word' id='word_1_17' title='bbox 1568 1917 1932 1975; x_wconf 0'>Wurmel0dG.</span>
      <span class='ocrx_word' id='word_1_18' title='bbox 2042 1931 2091 1971; x_wconf 20'>«ant</span>
      <span class='ocrx_word' id='word_1_19' title='bbox 2129 1931 2218 1973; x_wconf 53'>thie</span>
      <span class='ocrx_word' id='word_1_20' title='bbox 2261 1935 2466 1990; x_wconf 96'>amazing</span>
      <span class='ocrx_word' id='word_1_21' title='bbox 2510 1937 2782 1980; x_wconf 96'>double&quot;quote</span>
      <span class='ocrx_word' id='word_1_22' title='bbox 2826 1942 3000 1997; x_wconf 96'>single&#39;quote</span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
