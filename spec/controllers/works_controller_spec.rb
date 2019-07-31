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
          to match(/attachment. filename=.test_title[^\.]+\.ris/)
      end
    end
  end
end