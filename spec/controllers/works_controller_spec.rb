require 'rails_helper'

RSpec.describe WorksController, type: :controller do
  context "smoke tests" do
    context "standard work" do
      let(:work) { FactoryBot.create(:work, :with_assets)}

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
      end
    end
  end
end