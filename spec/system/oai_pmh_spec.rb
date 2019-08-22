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

  it "renders feed with just work" do
    visit(oai_provider_path(verb: "ListRecords", metadataPrefix: "oai_dc"))

    expect(page.status_code).to eq 200

    # parse strict, so we get an exception if it's not well-formed XML
    xml = Nokogiri::XML(page.body) { |config| config.strict }

    # validate XSD
    schema = Nokogiri::XML::Schema(File.read(oai_pmh_xsd_path))
    errors = schema.validate(xml)
    # PA Digital is at present asking for a dc:identifier.thumbnail element which
    # fails validation.
    expect(
      errors.count == 0 ||
      ( errors.count == 1 && errors.first.message.include?("identifier.thumbnail': This element is not expected.") )
    )

    # includes one item, which is the work, not the collection, not the non-published work.
    records = xml.xpath("//oai:record", oai: "http://www.openarchives.org/OAI/2.0/")
    expect(records.count).to eq (1)

    dc_contributors = xml.xpath("//dc:contributor", dc:"http://purl.org/dc/elements/1.1/").children.map(&:to_s)
    expect(dc_contributors.map).to include("G. Henle Verlag")

    dc_creators = xml.xpath("//dc:contributor", dc:"http://purl.org/dc/elements/1.1/").children.map(&:to_s)
    expect(dc_contributors.map).to include("G. Henle Verlag")

    record_id = records.first.at_xpath("./oai:header/oai:identifier", oai: "http://www.openarchives.org/OAI/2.0/")
    expect(record_id.text).to eq("oai:sciencehistoryorg:#{work.id}")

    # TODO test thumb URL, and that it's resolvable
  end
end
