require 'rails_helper'

describe MemberImagePresentation, type: :decorator do
  let(:rendered) { Nokogiri::HTML.fragment(presenter.display) }
  let(:wrapper_div) { rendered.at_css("div.member-image-presentation") }
  let(:presenter) { MemberImagePresentation.new(member) }

  describe "with asset" do
    let(:member) { create(:asset, :inline_promoted_file) }

    describe "large size" do
      let(:presenter) { MemberImagePresentation.new(member, size: :large) }

      it "has thumb, and two buttons" do
        expect(wrapper_div).to be_present
        expect(wrapper_div).to have_selector(".thumb img")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.view .btn")
      end
    end

    describe "non-published asset without auth" do
      let(:member) { create(:asset, published: false) }

      it "outputs only placeholder" do
        expect(wrapper_div).to be_present

        expect(wrapper_div).to have_selector(".thumb img.no-access-placeholder")

        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
      end
    end
  end

  describe "with child work" do
    describe "with non-published representative" do
      let(:member) { create(:work, representative: create(:asset, published: false)) }

      it "outputs only placeholder" do
        expect(wrapper_div).to be_present

        expect(wrapper_div).to have_selector(".thumb img.no-access-placeholder")

        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
      end
    end
  end
end
