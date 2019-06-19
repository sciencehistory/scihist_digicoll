require 'rails_helper'

describe RelatedUrlFilter do
  let(:opac_urls) {[
    "http://othmerlib.sciencehistory.org/record=1",
    "https://othmerlib.sciencehistory.org/record=2",
    "http://othmerlib.chemheritage.org/record=2"
  ]}
  let(:related_work_urls) {[
    "http://digital.sciencehistory.org/works/1212",
    "https://digital.sciencehistory.org/works/1212"
  ]}
  let(:generic_urls) {[
    "http://example.org/foo",
    "https://example.org/bar"
  ]}

  let(:all_urls) { opac_urls + related_work_urls + generic_urls }

  let(:filter) { RelatedUrlFilter.new(all_urls) }

  it "filters" do
    expect(filter.filtered_related_urls).to eq(generic_urls)
    expect(filter.opac_urls).to eq(opac_urls)
    expect(filter.related_work_urls).to eq(related_work_urls)
  end
end
