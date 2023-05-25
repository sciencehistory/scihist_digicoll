require 'rails_helper'


describe CollectionOpacUrls do
  let(:collection) do
    create(:collection,
          external_id: [
            {
              category: "object",
              value: "not this one"
            },
            {
              category: "bib",
              value: "b1234567999"
            }
          ]
        )
  end

  let(:service) { CollectionOpacUrls.new(collection) }

  it "returns opacURLs" do
    expect(service.opac_urls).to eq([ScihistDigicoll::Util.opac_url("b1234567")])
  end
end
