require 'rails_helper'

# Because creating real data is so slow, and feature tests pretty slow too,
# we try to do everything in one test, even though that's not great test design.
RSpec.feature "OAI-PMH feed", js: false do

  let!(:representative_asset) { create(:asset_with_faked_file) }

  # This one should be in feed:
  let!(:work) { create(:work, :with_complete_metadata,
    published: true,
    creator: [
      {
        category: "creator_of_work",
        value: "John Lennon"
      },
      {
        category: "editor",
        value: "G. Henle Verlag"
      }
    ],
    representative: representative_asset,
    members: [representative_asset]
  )}

  # Should not be in feed, unpublished:
  let!(:unpublished_work) { create(:work, :with_complete_metadata, title: "unpublished", published: false) }

  # Should not be in feed, a collection:
  let!(:collection) { create(:collection, published: true) }

  # We use this to validate OAI-pmh:
  let(:oai_pmh_xsd_path) { Rails.root + "spec/fixtures/xsd/OAI-PMH.xsd" }

  let(:public_work_url) { work_url(work) }
  let(:work_thumb_url) { download_derivative_url(work.leaf_representative, "download_medium", disposition: :inline) }
  let(:work_full_url) { download_derivative_url(work.leaf_representative, "download_full", disposition: :inline) }

  it "renders feed with just work" do
    visit(oai_provider_path(verb: "ListRecords", metadataPrefix: "oai_dc"))

    expect(page.status_code).to eq 200

    # parse strict, so we get an exception if it's not well-formed XML
    xml = Nokogiri::XML(page.body) { |config| config.strict }

    # validate XSD
    schema = Nokogiri::XML::Schema(File.read(oai_pmh_xsd_path))
    errors = schema.validate(xml)
    expect(errors.count == 0)

    # includes one item, which is the work, not the collection, not the non-published work.
    records = xml.xpath("//oai:record", oai: "http://www.openarchives.org/OAI/2.0/")
    expect(records.count).to eq (1)
    record = records.first

    dc_contributors = record.xpath("//dc:contributor", dc:"http://purl.org/dc/elements/1.1/").children.map(&:to_s)
    expect(dc_contributors.map).to include("G. Henle Verlag")

    dc_creators = record.xpath("//dc:contributor", dc:"http://purl.org/dc/elements/1.1/").children.map(&:to_s)
    expect(dc_contributors.map).to include("G. Henle Verlag")

    record_id = record.at_xpath("./oai:header/oai:identifier", oai: "http://www.openarchives.org/OAI/2.0/")
    expect(record_id.text).to eq("oai:sciencehistoryorg:#{work.id}")

    dc_identifiers = record.xpath("//dc:identifier", dc:"http://purl.org/dc/elements/1.1/").collect(&:text)
    expect(dc_identifiers).to include(public_work_url)
    # PA digital wants the thumb in there too, I dunno.
    expect(dc_identifiers).to include(work_thumb_url)

    expect(record.at_xpath("//edm:object", edm: "http://www.europeana.eu/schemas/edm/")&.text).to eq work_full_url
  end
end
