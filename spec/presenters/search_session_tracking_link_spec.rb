require 'rails_helper'

describe SearchSessionTrackingLink, type: :presenter do
  let(:results_index) { 2 }
  let(:work) { create(:work) }
  let(:subject) { SearchSessionTrackingLink.new(work, index: results_index) }


  # We are mocking a BUNCH of Blacklight, to let the SearchSessionTrackingLink get
  # the context. This is pretty fragile, if BL changes it might actually break our
  # object, and the test would falsely miss it, and I'm not sure how much we're really
  # testing.
  #
  # But not a lot of great options here, we will also try some system level tests separately.

  let(:mocked_per_page) { 25 }
  let(:mocked_search_id) { 1001 }
  let(:mocked_response_start) { 25 }

  before do
    allow(helpers).to receive(:session).and_return({
      :search => {
        'per_page' => mocked_per_page
      }
    })

    allow(subject).to receive(:current_search_session).and_return(
      OpenStruct.new(id: mocked_search_id)
    )

    # omg i know
    helpers.controller.instance_variable_set("@response", OpenStruct.new(start: mocked_response_start))
  end

  it "can create session_tracking_params" do
    track_link = subject.tracking_search_hit_link

    expect(track_link).to be_present
    expect(track_link).to start_with(helpers.track_catalog_path(work.to_param))

    parsed_uri = Addressable::URI.parse(track_link)
    expect(parsed_uri.query_values["counter"]).to eq((results_index + mocked_response_start + 1).to_s)
    expect(parsed_uri.query_values["per_page"]).to eq(mocked_per_page.to_s)
    expect(parsed_uri.query_values["search_id"]).to eq(mocked_search_id.to_s)
  end
end
