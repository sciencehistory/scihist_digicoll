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

  describe "case insensitivity of known items" do
    it "redirects standard beckman url" do
      get "/oral-histories/beckman-arnold-o-14A"
      expect(response).to have_http_status(301) # moved permanently
      expect(response).to redirect_to("#{standard_base_url}/works/sx61dn215")
    end

    it "redirects alternate case beckman seen on web" do
      pending "implementation see https://github.com/sciencehistory/scihist_digicoll/issues/1093"

      get "/oral-histories/beckman-arnold-o-14a"
      expect(response).to have_http_status(301) # moved permanently
      expect(response).to redirect_to("#{standard_base_url}/works/sx61dn215")
    end
  end


  it "handles unrecognized with a nice 404" do
    get "/some_url/never_heard_of_it"
    expect(response).to have_http_status(:not_found)
    expect(response).to render_template("static/oh_legacy_url_not_found")
  end

  it "handles unrecognized .pdf link with a nice 404" do
    get "/some_url/never_heard_of_it.pdf"
    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response).to render_template("static/oh_legacy_url_not_found")
  end
end
