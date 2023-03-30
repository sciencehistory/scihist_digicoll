require 'rails_helper'

describe HocrComponent do
  describe "#strip_ids_and_html_headers" do
    let (:hocr) { File.read('spec/test_support/hocr_xml/hocr.xml')}


    it "can return the contents of the body with tags stripped of IDs." do
      processed_hocr =  HocrComponent.new(hocr).html_body_without_ids
      expect(processed_hocr).to include '<span class="ocrx_word" title="bbox 1405 564 1556 606; x_wconf 96">Supply</span>'
      expect(processed_hocr).not_to include  'id="word_1_1"'
    end
  end
end
