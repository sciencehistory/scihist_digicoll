require 'rails_helper'
RSpec.describe Admin::CartItemsController, :logged_in_user, type: :controller, queue_adapter: :test do
  context "smoke test for report" do
    # See also the test for the cart_exporter itself at 
    # at spec/services/cart_exporter_spec.rb
    let(:work_1) { FactoryBot.create(:work, :with_assets)}
    let(:work_2) { FactoryBot.create(:work, :with_assets)}
    let(:work_3) { FactoryBot.create(:work, :with_assets)}
	  before do
	    controller.current_user.works_in_cart = [work_1, work_2, work_3]
	  end

    it "export smoke test" do
      post :report
      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).
        to eq 'text/csv'
      expect(response.headers["Content-Disposition"]).
        to match %r{attachment; filename=\"cart-report-.*.csv\"}
    end     
  end
end
