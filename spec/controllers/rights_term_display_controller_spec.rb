require "rails_helper"

describe RightsTermDisplayController do
  describe "for unknown param" do
    let(:rights_param) { "no-such-param-id" }

    it "404s" do
      expect {
        get :show, params: { id: rights_param }
      }.to raise_error(ActionController::RoutingError)
    end
  end

  describe "for valid param" do
    render_views

    let(:rights_param) { "NoC-US" }
    let(:rights_term) { RightsTerm.find_by_param_id(rights_param) }

    it "displays page" do
      get :show, params: { id: rights_param }

      expect(response).to have_http_status(200)
      expect(response.body).to include(rights_term.description)
    end
  end
end
