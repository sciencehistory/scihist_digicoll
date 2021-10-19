require 'rails_helper'

describe WorkImageShowComponent, type: :component do
  context "thumbnails" do
    let(:asset1) {
      create(:asset_with_faked_file,
        title: "First asset (representative)",
        faked_derivatives: {},
        position: 0)
    }
    let(:asset2) {
      create(:asset_with_faked_file,
        title: "First asset (representative)",
        faked_derivatives: {},
        position: 1)
    }

    context "first image is represnetative" do
      let(:work) {
        create(:work, :published, :with_complete_metadata, members: [asset1, asset2], representative: asset1)
      }

      it "displays only the second thumb in small list" do
        render_inline described_class.new(work)

        # representative is hero thumb
        hero = page.first(".show-hero .member-image-presentation")
        expect(hero.first("a.thumb")["data-member-id"]).to eq(asset1.friendlier_id)
        expect(hero.first("a.thumb")["aria-label"]).to eq "View"
        expect(hero.first(".downloads button").text.strip).to eq "Download"
        expect(hero.first(".downloads button")["aria-label"]).to be_nil

        # only the second asset is included in the smaller thumb list
        thumbs = page.all(".show-member-list-item .member-image-presentation")
        expect(thumbs.length).to be(1)

        expect(thumbs[0].first("a.thumb")["aria-label"]).to eq "View Image 2"
        expect(thumbs[0].first(".downloads button")["aria-label"]).to eq "Download Image 2"
      end
    end

    context "non-first image is representative" do
      let(:work) {
        create(:work, :published, :with_complete_metadata, members: [asset1, asset2], representative: asset2)
      }

      it "displays both thumbs in small thumb list" do
        render_inline described_class.new(work)

        # representative is hero thumb
        hero = page.first(".show-hero .member-image-presentation")
        expect(hero.first("a.thumb")["data-member-id"]).to eq(asset2.friendlier_id)
        expect(hero.first("a.thumb")["aria-label"]).to eq "View"
        expect(hero.first(".downloads button").text.strip).to eq "Download"
        expect(hero.first(".downloads button")["aria-label"]).to be_nil


        # But BOTH thumbs wind up repeated as small thumbs
        thumbs = page.all(".show-member-list-item .member-image-presentation")
        expect(thumbs.length).to be(2)

        expect(thumbs[0].first("a.thumb")["aria-label"]).to eq "View Image 1"
        expect(thumbs[0].first(".downloads button")["aria-label"]).to eq "Download Image 1"

        expect(thumbs[1].first("a.thumb")["aria-label"]).to eq "View Image 2"
        expect(thumbs[1].first(".downloads button")["aria-label"]).to eq "Download Image 2"
      end
    end
  end
end
