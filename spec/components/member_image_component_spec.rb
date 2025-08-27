require 'rails_helper'

describe MemberImageComponent, type: :component do
  let(:rendered) { render_inline(presenter) }
  let(:wrapper_div) { rendered.at_css("div.member-image-presentation") }
  let(:presenter) { MemberImageComponent.new(member) }

  describe "with asset" do
    let(:parent) { create(:public_work, members: [create(:asset_with_faked_file), create(:asset_with_faked_file)] ) }
    let(:member) { parent.members.first }

    describe "large size" do
      let(:presenter) { MemberImageComponent.new(member, size: :large) }

      it "has thumb, and two buttons" do
        expect(wrapper_div).to be_present
        expect(wrapper_div).to have_selector(".thumb img")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.view .btn")
      end

      it "hides poster image from accessible tech" do
        # in large size, poster image link just duplicates the "view" link, it can/should be hidden
        # https://www.sarasoueidan.com/blog/keyboard-friendlier-article-listings/.

        poster_link = wrapper_div.at("a.thumb")
        expect(poster_link["aria-label"]).to be_nil
        expect(poster_link["tabindex"]).to eq "-1"
        expect(poster_link["aria-hidden"]).to eq "true"
      end

      describe "with fetchpriority:high" do
        let(:presenter) { MemberImageComponent.new(member, fetchpriority: :high) }
        it "includes attribute on img tag" do
          expect(wrapper_div.at_css(".thumb img[fetchpriority=high]")).to be_present
        end
      end
    end

    describe "with whole-work download options passed in" do
      let(:presenter) { MemberImageComponent.new(member, size: :large, work_download_options: WorkDownloadOptionsCreator.new(parent).options) }

      it "download button includes whole-work derivatives" do
        expect(wrapper_div).to have_selector(".btn-group.downloads a.dropdown-item:contains('ZIP')")
        expect(wrapper_div).to have_selector(".btn-group.downloads a.dropdown-item:contains('PDF')")
      end
    end

    describe "small size" do
      it "has thumb and a download button" do
        expect(wrapper_div).to be_present
        expect(wrapper_div).to have_selector(".thumb img")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.downloads .btn")

        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
      end

      it "does not include whole-work derivatives" do
        expect(wrapper_div).not_to have_selector(".btn-group.downloads a.dropdown-item:contains('ZIP')")
        expect(wrapper_div).not_to have_selector(".btn-group.downloads a.dropdown-item:contains('PDF')")
      end
    end

    describe "non-published asset without auth" do
      let(:member) { create(:asset, published: false) }

      it "outputs only placeholder" do
        expect(wrapper_div).to be_present



        expect(wrapper_div).to have_selector(".thumb img.not-available-placeholder")

        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
      end
    end

    describe "non-published asset with auth", logged_in_user: true do
      let(:member) { create(:asset, published: false) }

      it "outputs image with 'private' warning label" do
        expect(wrapper_div).to be_present
        expect(wrapper_div).to have_selector(".thumb img")
        expect(wrapper_div).not_to have_selector(".thumb img.not-available-placeholder")

        expect(wrapper_div).to have_text("Private")
      end
    end

    describe "image_label arg" do
      let(:presenter) { MemberImageComponent.new(member, image_label: "Image 2") }

      it "creates aria-labels on links" do
        expect(wrapper_div.at("a.thumb")["aria-label"]).to eq "View Image 2"
        expect(wrapper_div.at("div.downloads button")["aria-label"]).to eq "Download Image 2"
      end
    end
  end

  describe "with child work" do
    let(:member) { create(:work, representative: create(:asset_with_faked_file)) }

    describe "large size" do
      let(:presenter) { MemberImageComponent.new(member, size: :large) }

      it "has thumb and THREE buttons" do
        expect(wrapper_div).to be_present
        expect(wrapper_div).to have_selector(".thumb img")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.view .btn")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.info .btn")

        # info button has aria-label
        expect(wrapper_div.at(".action-item-bar .action-item.info .btn")["aria-label"]).to eq "Info on #{member.title}"
      end


    end

    describe "small size" do
      it "has thumb and only info button" do
        expect(wrapper_div).to be_present
        expect(wrapper_div).to have_selector(".thumb img")
        expect(wrapper_div).to have_selector(".action-item-bar .action-item.info .btn")
        expect(wrapper_div.at(".action-item-bar .action-item.info .btn")["aria-label"]).to eq "Info on #{member.title}"

        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
      end
    end

    describe "with non-published representative" do
      let(:member) { create(:work, representative: create(:asset, published: false)) }

      it "outputs only placeholder" do
        expect(wrapper_div).to be_present

        expect(wrapper_div).to have_selector(".thumb img.not-available-placeholder")

        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
      end
    end

    describe "with no representative" do
      let(:member) { create(:work) }

      it "outputs only placeholder" do
        expect(wrapper_div).to be_present

        expect(wrapper_div).to have_selector(".thumb img.not-available-placeholder")

        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.downloads .btn")
        expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
      end
    end
  end

  describe "with nil argument" do
    let(:member) { nil }

    it "outputs only placeholder" do
      expect(wrapper_div).to be_present

      expect(wrapper_div).to have_selector(".thumb img.not-available-placeholder")

      expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.downloads .btn")
      expect(wrapper_div).not_to have_selector(".action-item-bar .action-item.view .btn")
    end
  end
end
