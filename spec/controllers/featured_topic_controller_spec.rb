require 'rails_helper'

RSpec.describe FeaturedTopicController, solr: true, type: :controller do
  describe "basic featured topic" do
    describe "smoke test" do
      it "can see page" do
        get :index, params: { slug: 'scientific-education' }
        expect(response).to have_http_status(:success)
      end
    end
  end
end
