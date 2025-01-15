require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what
# we want
describe CatalogController, type: :controller do

  # Temporarily enable bot detection
  around(:each) do |example|
    orig_enabled = BotDetectController.enabled

    BotDetectController.enabled = true
    BotDetectController.rack_attack_init

    example.run

    BotDetectController.enabled = orig_enabled
    BotDetectController.rack_attack_init
  end


  it "redirects when requested" do
    request.env[BotDetectController.env_challenge_trigger_key] = "true"
    get :index

    expect(response).to redirect_to(bot_detect_challenge_path(dest: search_catalog_path))
  end

  # we configured this to try to exempt fetch/ajax to #facet
  it "does not redirect from exempted action and request state" do
    request.headers["sec-fetch-dest"] = "empty"
    get :facet, params: { id: "subject_facet" }

    expect(response).to have_http_status(:success) # not a redirect
  end
end
