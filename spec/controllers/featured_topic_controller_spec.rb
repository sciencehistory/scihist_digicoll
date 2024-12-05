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

   describe "#facet", indexable_callbacks: true do
    render_views

    let(:topic_id) { 'color' }

    let(:featured_subjects) { FeaturedTopic.from_slug(topic_id).subjects.slice(0..7) }

    let!(:featured_work) { create(:public_work, subject: featured_subjects) }
    let!(:non_featured_work) { create(:public_work, subject: ["Outside Subject 1", "Outside Subject 2"]) }

    it "includes only featured work values" do
      get :facet, params: {
        id:    "subject_facet",
        slug:  topic_id
      }

      doc = Nokogiri::HTML(response.body)

      featured_work.subject.each do |subject|
        expect(doc).to have_selector(".facet-values li", text: subject)
      end

      non_featured_work.subject.each do |subject|
        expect(doc).not_to have_selector(".facet-values li", text: subject)
      end
    end
  end
end
