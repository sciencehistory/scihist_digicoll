require 'rails_helper'

RSpec.describe StaticController, type: :controller do
  context "Static pages" do
    %w(about contact faq policy).each do |page_label|
      it "shows the static #{page_label} page as expected" do
        get page_label.to_s, as: :html
        expect(response.status).to eq(200)
      end
    end
  end
end