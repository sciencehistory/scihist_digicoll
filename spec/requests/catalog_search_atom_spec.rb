require 'rails_helper'

RSpec.describe CatalogController, solr: true, indexable_callbacks: true, type: :request do
  let(:parsed_response) do
    Nokogiri::XML::Document.parse(response.body) do |config|
      config.strict
    end
  end

  let(:namespaces) do
    {
      atom: "http://www.w3.org/2005/Atom",
      opensearch: "http://a9.com/-/spec/opensearch/1.1/",
      media: "http://search.yahoo.com/mrss/"
    }
  end

  describe "for main catalog page" do
    let!(:work1) do
      create(:public_work, :with_complete_metadata, title: "priceless work")
    end

    let!(:work2) do
      create(:public_work, :with_complete_metadata, title: "ordinary work")
    end

    let!(:collection) do
      create(:collection, published: true, title: 'a nice collection')
    end

    before do
      get search_catalog_path(format: :atom)
    end

    it "produces valid Atom XML" do
      xsd = Nokogiri::XML::Schema(File.open(Rails.root + "spec/test_support/xml_schema/atom.xsd"))
      expect(xsd.valid?(parsed_response))

      expect(parsed_response.xpath("./atom:feed/atom:entry", namespaces).count).to eq 3

      expect(parsed_response.at_xpath("./atom:feed/atom:link[@rel='alternate'][@type='text/html']", namespaces)["href"]).to eq(
        search_catalog_url
      )
      expect(parsed_response.at_xpath("./atom:feed/opensearch:totalResults", namespaces).text).to eq "3"
    end
  end

  describe "searching in a custom controller collection" do
    let!(:collection) do
      create(:collection,
              friendlier_id: ScihistDigicoll::Env.lookup(:oral_history_collection_id)
      ).tap do |col|
        # need to create with existing collection so it gets Solr indexed
        create(:public_work, contained_by: [col])
        create(:public_work, contained_by: [col])
      end
    end

    it "produces expected atom results" do
      get collection_path(collection.friendlier_id, format: :atom)
      expect(parsed_response.xpath("./atom:feed/atom:entry", namespaces).count).to eq 2
    end
  end
end
