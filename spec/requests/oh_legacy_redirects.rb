require 'rails_helper'

describe "Oral history legacy site redirects" do
  let(:legacy_host) { ScihistDigicoll::Env.lookup!(:oral_history_legacy_host) }
  let(:standard_base_url) { ScihistDigicoll::Env.lookup!(:app_url_base) }

  let(:redirects) { YAML.load_file(Rails.root + "config/oral_history_legacy_redirects.yml") }
  let(:known_item_source_path) { redirects.keys.first }
  let(:known_item_target_path) { redirects.values.first }

  before do
    # send all requests to this host, our legacy OH host
    host! legacy_host
  end

  it "redirects the homepage to OH collection" do
    get "/"
    expect(response).to have_http_status(301) # moved permanently
    expect(response).to redirect_to("#{standard_base_url}/collections/#{ScihistDigicoll::Env.lookup!(:oral_history_collection_id)}")
  end

  it "redirects a known item" do
    get known_item_source_path
    expect(response).to have_http_status(301) # moved permanently
    expect(response).to redirect_to("#{standard_base_url}#{known_item_target_path}")
  end

  it "handles unrecognized with a nice 404" do
    get "/some_url/never_heard_of_it"
    expect(response).to have_http_status(:not_found)
    expect(response).to render_template("static/oh_legacy_url_not_found")
  end
end
