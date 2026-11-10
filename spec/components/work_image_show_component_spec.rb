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

    context "published work" do
      context "first image is representative" do
        let(:work) {
          create(:work, :published, :with_complete_metadata, members: [asset1, asset2], representative: asset1)
        }


        it "displays only the second thumb in small list" do
          render_inline described_class.new(work)

          # representative is hero thumb, which should have a "view" button, and have
          # poster image with duplicate link taken out of accessible tech.
          # https://www.sarasoueidan.com/blog/keyboard-friendlier-article-listings/.

          hero = page.first(".show-hero .member-image-presentation")
          hero_poster = hero.first("a.thumb")

          expect(hero_poster["data-member-id"]).to eq(asset1.friendlier_id)
          expect(hero_poster["aria-label"]).to be_nil
          expect(hero_poster["tabindex"]).to eq "-1"
          expect(hero_poster["aria-hidden"]).to eq "true"

          expect(hero.first(".downloads button").text.strip).to eq "Download"
          # this serves as download link for the whole item, "Download" label is sufficient
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

          # representative is hero thumb, which has a Download and View link
          hero = page.first(".show-hero .member-image-presentation")
          expect(hero.first("a.thumb")["data-member-id"]).to eq(asset2.friendlier_id)
          expect(hero.first("a.thumb")["aria-label"]).to be_nil

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

    context "work with unpublished assets" do
      let(:work) {
        create(:work, :published, :with_complete_metadata, members: [asset1, asset2], representative: asset1)
      }
      let(:asset2) {
        create(:asset_with_faked_file,
          published: false,
          title: "First asset (representative)",
          faked_derivatives: {},
          position: 1)
      }

      it "does not show unpublished asset" do
        render_inline described_class.new(work)
        hero = page.first(".show-hero .member-image-presentation")
        hero_poster = hero.first("a.thumb")
        expect(hero_poster["data-member-id"]).to eq(asset1.friendlier_id)
        thumbs = page.all(".show-member-list-item .member-image-presentation")
        expect(thumbs.length).to be(0)
      end

      it "shows unpublished asset to a logged-in admin user", logged_in_user: :admin do
        render_inline described_class.new(work)
        hero = page.first(".show-hero .member-image-presentation")
        hero_poster = hero.first("a.thumb")
        expect(hero_poster["data-member-id"]).to eq(asset1.friendlier_id)
        thumbs = page.all(".show-member-list-item .member-image-presentation")
        expect(thumbs.length).to be(1)
      end
    end
  end

  describe "#has_transcription_or_translation?" do
    let(:work) do
      create(:public_work, members: [create(:asset_with_faked_file, handwriting_transcription: "some handwriting")])
    end
    let(:component) { described_class.new(work) }

    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(feature_flag)
      render_inline component
    end

    describe "with the feature flag on" do
      let(:feature_flag) { true }

      it "counts a handwriting transcription" do
        expect(component.has_transcription_or_translation?).to be true
      end
    end

    describe "with the feature flag off" do
      let(:feature_flag) { false }

      it "ignores a handwriting transcription" do
        expect(component.has_transcription_or_translation?).to be false
      end
    end
  end
end
