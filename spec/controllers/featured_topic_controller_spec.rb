require 'rails_helper'

RSpec.describe FeaturedTopicController, solr: true, type: :controller do
  render_views

  describe "basic featured topic" do
    describe "smoke test" do
      it "can see page" do
        get :index, params: { slug: 'scientific-education' }
        expect(response).to have_http_status(:success)
      end
    end

    describe "404 response" do
      it "for no such topic" do
        expect {
          get :index, params: { slug: 'no-such-topic' }
        }.to raise_error(ActionController::RoutingError)
      end

      it "for path-type topic" do
        expect {
          get :index, params: { slug: 'oral-histories' }
        }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
