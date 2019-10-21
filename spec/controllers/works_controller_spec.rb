require 'rails_helper'

RSpec.describe WorksController, type: :controller do
  context "smoke tests" do
    context "standard work" do
      let(:work){create(:work, members: [create(:asset)])}

      before do
        work.representative = work.members.first
        work.save
        allow(work.members.first).to receive(:content_type).and_return("audio/mpeg")
      end


      it "shows the work as expected" do
        get :show, params: { id: work.friendlier_id }, as: :html
        expect(response.status).to eq(200)
      end

      it 'allows user to download RIS citation' do
        get :show, params: { id: work.friendlier_id }, as: :ris
        expect(response.status).to eq(200)
        expect(response.body).to include "TI  - Test title"
        expect(response.body).to include "M2  - Courtesy of Science History Institute."
        expect(response.content_type).to eq "application/x-research-info-systems"
        expect(response.headers["Content-Disposition"]).
          to eq "attachment; filename=\"test_title_#{ work.friendlier_id }.ris\""
      end

      it "delivers oai_dc from XML request" do
        get :show, params: { id: work.friendlier_id }, as: :xml
        expect(response.status).to eq(200)
        expect(response.content_type).to eq "application/xml"

        parsed = Nokogiri::XML(response.body)
        expect(parsed.root&.namespace&.href).to eq "http://www.openarchives.org/OAI/2.0/oai_dc/"
        expect(parsed.root&.name).to eq "dc"
      end
    end
  end

  context("#viewer_images_info") do
    let(:work) { create(:work, members: [create(:asset_with_faked_file)]) }

    it "returns JSON" do
      get :viewer_images_info, params: { id: work.friendlier_id }, as: :json
      expect(response.status).to eq(200)
      expect(response.content_type).to eq "application/json"
      expect(JSON.parse(response.body)).to be_kind_of(Array)
    end
  end
end
