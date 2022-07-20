require 'rails_helper'

describe WorkOaiDcSerialization do
  let(:member_asset1) { create(:asset, :inline_promoted_file)}
  let(:member_asset2) { create(:asset, :inline_promoted_file)}
  let(:collection) { create(:collection, title: "My Local Collection") }
  let(:work) { create(:work, :with_complete_metadata,
    description: "This starts out with <b>tags</b>\n\nAnother paragraph",
    extent: ["8.75 in. H x 5.6 in. W"],
    place: [{ category: "place_of_creation", value: "Université de Bordeaux (1441-1970"}],
    creator: [
      { category: :author, value: "Smith, Joe" },
      { category: :editor, value: "Editor, Joe" }
    ],
    rights_holder: "Science History Institute",
    representative: member_asset1,
    members: [member_asset1, member_asset2],
    contained_by: [collection]
  )}

  # hacky probably a better way to do this. :(
  let(:app_base) { "#{ScihistDigicoll::Env.app_url_base_parsed.scheme}://#{ScihistDigicoll::Env.app_url_base_parsed.host}" }
  let(:public_work_url) { app_base + Rails.application.routes.url_helpers.work_path(work) }
  let(:work_thumb_url) { app_base + Rails.application.routes.url_helpers.download_derivative_path(work.representative, :thumb_large_2X, disposition: "inline") }
  let(:member_asset1_url) { app_base + Rails.application.routes.url_helpers.download_derivative_path(member_asset1.leaf_representative, :download_full, disposition: "inline") }
  let(:member_asset2_url) { app_base + Rails.application.routes.url_helpers.download_derivative_path(member_asset2.leaf_representative, :download_full, disposition: "inline") }

  let(:instance) { WorkOaiDcSerialization.new(work)}

  def creator_values(work, role)
    work.creator.find_all { |creator| creator.category == role }.collect(&:value)
  end

  it "serializes" do
    xml_str = instance.to_oai_dc

    # is well-formed XML
    xml = Nokogiri::XML(xml_str) { |config| config.strict }

    container = xml.at_xpath("./oai_dc:dc")
    expect(container).to be_present

    # PA digital wants both URL in dc:identifiers
    dc_identifiers = container.xpath("./dc:identifier").collect(&:text)
    expect(dc_identifiers).to include public_work_url

    expect(container.at_xpath("./dc:title").text).to eq work.title
    expect(container.at_xpath("./dc:rights").text).to eq work.rights

    expect(container.at_xpath("./dc:creator").text).to eq creator_values(work, "author").first
    expect(container.at_xpath("./dc:contributor").text).to eq creator_values(work, "editor").first

    expect(container.at_xpath("./dc:description").text).to eq work.description.gsub(/<[^>]*>/, '') # strip html tags

    #expect(container.at_xpath("./dc:format").text).to eq work.file_sets.first.mime_type

    expect(container.at_xpath("./dc:language").text).to eq work.language.first
    expect(container.at_xpath("./dc:subject").text).to eq work.subject.first
    expect(container.at_xpath("./dc:type").text).to eq work.format.first


    expect(container.at_xpath("./edm:rights").text).to eq work.rights
    expect(container.at_xpath("./edm:hasType").text).to eq work.genre.first.downcase

    expect(container.at_xpath("./dpla:originalRecord").text).to eq public_work_url
    expect(container.at_xpath("./edm:preview").text).to eq work_thumb_url

    expect(container.xpath("./edm:object").collect(&:text)).to contain_exactly(member_asset1_url, member_asset2_url)

    expect(container.at_xpath("./dcterms:isPartOf")&.text).to eq collection.title
    expect(container.at_xpath("./dcterms:extent")&.text).to eq work.extent.first
    expect(container.at_xpath("./dcterms:spatial")&.text).to eq work.place.first.value
    expect(container.at_xpath("./dcterms:rightsholder")&.text).to eq work.rights_holder

    # TODO xml["dc"].format for mime/types of all included files
    # TODO test more than one thing?
  end

  # a simple smoke test
  describe "video work" do
    let(:work) { create(:video_work) }

    it "serializes" do
      xml_str = instance.to_oai_dc

      # is well-formed XML
      xml = Nokogiri::XML(xml_str) { |config| config.strict }

      container = xml.at_xpath("./oai_dc:dc")
      expect(container).to be_present

      # PA digital wants both URL in dc:identifiers
      dc_identifiers = container.xpath("./dc:identifier").collect(&:text)
      expect(dc_identifiers).to include public_work_url

      expect(container.at_xpath("./dc:title").text).to eq work.title
      expect(container.at_xpath("./dc:rights").text).to eq work.rights

      expect(container.at_xpath("./dc:type").text).to eq work.format.first

      expect(container.at_xpath("./dpla:originalRecord").text).to eq public_work_url
      expect(container.at_xpath("./edm:preview").text).to eq work_thumb_url

      # we don't have an original high-res image and aren't currently supporting
      # video downloads anyway, so definitely no valid edm:object is available.
      expect(container.at_xpath("./edm:object")).to be_nil
    end
  end
end
