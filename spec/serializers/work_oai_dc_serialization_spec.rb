require 'rails_helper'

describe WorkOaiDcSerialization do
  let(:member_asset) { create(:asset, :inline_promoted_file)}
  let(:work) { create(:work, :with_complete_metadata, representative: member_asset, members: [member_asset])}

  # hacky probably a better way to do this. :(
  let(:app_base) { "#{ScihistDigicoll::Env.app_url_base_parsed.scheme}://#{ScihistDigicoll::Env.app_url_base_parsed.host}" }
  let(:public_work_url) { app_base + Rails.application.routes.url_helpers.work_path(work) }
  let(:work_thumb_url) { app_base + Rails.application.routes.url_helpers.download_derivative_path(work.representative, :download_medium, disposition: "inline") }
  let(:full_jpg_url) { app_base + Rails.application.routes.url_helpers.download_derivative_path(work.representative, :download_full, disposition: "inline") }

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

    # PA digital wants both URL and thumbnail URL in dc:identifiers
    dc_identifiers = container.xpath("./dc:identifier").collect(&:text)
    expect(dc_identifiers).to include public_work_url
    expect(dc_identifiers).to include work_thumb_url

    expect(container.at_xpath("./dc:title").text).to eq work.title
    expect(container.at_xpath("./dc:rights").text).to eq work.rights

    expect(container.at_xpath("./dc:creator").text).to eq creator_values(work, "author").first

    expect(container.at_xpath("./dc:description").text).to eq work.description

    #expect(container.at_xpath("./dc:format").text).to eq work.file_sets.first.mime_type

    expect(container.at_xpath("./dc:language").text).to eq work.language.first
    expect(container.at_xpath("./dc:subject").text).to eq work.subject.first
    expect(container.at_xpath("./dc:type").text).to eq work.format.first


    expect(container.at_xpath("./edm:rights").text).to eq work.rights
    expect(container.at_xpath("./edm:hasType").text).to eq work.genre.first.downcase

    expect(container.at_xpath("./dpla:originalRecord").text).to eq public_work_url
    expect(container.at_xpath("./edm:object").text).to eq full_jpg_url
    expect(container.at_xpath("./edm:preview").text).to eq work_thumb_url

    # TODO make sure we take html out of description
    # TODO xml["dc"].format for mime/types of all included files
    # TODO test more than one thing?
    # TODO test contributors not just creators
  end

end
