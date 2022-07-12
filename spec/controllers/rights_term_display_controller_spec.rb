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

  describe "for valid rights param" do
    render_views

    let(:rights_param) { "NoC-US" }
    let(:rights_term) { RightsTerm.find_by_param_id(rights_param) }

    it "displays page" do
      get :show, params: { id: rights_param }

      expect(response).to have_http_status(200)
      expect(response.body).to include(rights_term.description)
    end
  end

  describe "with rights param and work with rights holder" do
    render_views

    let(:rights_param) { "NoC-US" }
    let(:rights_term) { RightsTerm.find_by_param_id(rights_param) }
    let(:work) { create(:work, rights: rights_term.id, rights_holder: "Some Rightsholder") }
    let(:work_friendlier_id) { work.friendlier_id }

    it "displays page with rights holder" do
      get :show, params: { id: rights_param, work_id: work_friendlier_id }

      expect(response).to have_http_status(200)
      expect(response.body).to include(rights_term.description)
      expect(response.body).to include(work.rights_holder)
    end

    describe "with conflicting params" do
      let(:work) { create(:work, rights: "http://rightsstatements.org/vocab/InC-EDU/1.0/") }

      it "won't display page, 404s" do
        expect {
          get :show, params: { id: rights_param, work_id: work_friendlier_id }
        }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
