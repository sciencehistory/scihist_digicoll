require 'rails_helper'

describe WorkImageShowComponent, type: :component do
  context "thumbnails" do
    let(:asset1) {
      create(:asset_with_faked_file, faked_derivatives: {}, position: 0)
    }
    let(:asset2) {
      create(:asset_with_faked_file, faked_derivatives: {},  position: 1)
    }
    let(:asset3) {
      create(:asset_with_faked_file, faked_derivatives: {},  position: 2)
    }
    let(:asset4) {
      create(:asset_with_faked_file, faked_derivatives: {},  position: 3)
    }
    let(:asset5) {
      create(:asset_with_faked_file, faked_derivatives: {},  position: 4)
    }
    let(:members) {[asset1, asset2, asset3, asset4, asset5]}
    let(:work) {
      create(:work, :published, members: members, representative: asset1)
    }

    let(:hero_friendlier_id) do
      hero = page.first(".show-hero .member-image-presentation")
      hero.first("a.thumb")["data-member-id"]
    end

    let(:members_per_batch) do
      page.first('*[data-trigger="lazy-member-images"]')['data-members-per-batch']
    end

    let(:other_thumbs_friendlier_id_list) do
      page.all(".show-member-list-item .member-image-presentation a.thumb").map { |thumb| thumb["data-member-id"] }
    end
    context "published work" do
      context "first image is representative" do
        it "shows the representative at the top, two more images underneath" do
          html = render_inline described_class.new(work, members_per_batch: 3)

          expect(members_per_batch).to eq "3"
          expect(hero_friendlier_id).to eq asset1.friendlier_id
          thumbs = page.all(".show-member-list-item .member-image-presentation")
          expect(thumbs.length).to be(2)
          expect(other_thumbs_friendlier_id_list).to eq [ asset2.friendlier_id, asset3.friendlier_id ]
          # JS code will fetch more more thumbnails on request, starting with the fourth thumbnail
          # (next-start-index starts at zero)
          expect(page.first('*[data-trigger="lazy-member-images"]')['data-start-index']).to eq "3"
        end
      end

      context "non-first image is representative" do
        let(:work) {
          create(:work, :published, :with_complete_metadata, members: members, representative: asset2)
        }
        it "displays all three thumbnails in small thumb list" do
          render_inline described_class.new(work, members_per_batch: 3)
          expect(hero_friendlier_id).to eq(asset2.friendlier_id)
          expect(other_thumbs_friendlier_id_list).to eq [ asset1.friendlier_id, asset2.friendlier_id, asset3.friendlier_id ]
          expect(page.first('*[data-trigger="lazy-member-images"]')['data-start-index']).to eq "3"
        end
      end
    end

    context "work with five assets, the first two of which are unpublished" do
      let(:asset1) {
        create(:asset_with_faked_file, published: false, faked_derivatives: {}, position: 0)
      }
      let(:asset2) {
        create(:asset_with_faked_file, published: false, faked_derivatives: {}, position: 1)
      }
      context "user not logged in" do
        it "does not show a hero image, since the representative is unpublished" do
          expect(members.map { |x| [x.position, x.published?]}).to eq [
            [0, false], [1, false],
            [2, true], [3, true], [4, true]
          ]
          render_inline described_class.new(work)
          expect(page.find_all(".show-hero .member-image-presentation a.thumb").count).to eq 0
        end
        it "if the user requests two images, the first two viewable images are shown (asset3 and asset4)" do
          render_inline described_class.new(work, members_per_batch: 2)
          # no hero image
          expect(page.find_all(".show-hero .member-image-presentation a.thumb").count).to eq 0
          # shows 3 and 4
          expect(other_thumbs_friendlier_id_list).to eq [ asset3.friendlier_id, asset4.friendlier_id ]
        end
        it "the next batch of thumbnails fetched will start with asset5)" do
          component = described_class.new(work, members_per_batch: 2)
          render_inline component
          viewable_members = component.ordered_viewable_members_scope.to_a
          # next start index is 2 (i.e. the third VIEWABLE member)
          next_start_index =  page.first('*[data-trigger="lazy-member-images"]')['data-start-index'].to_i
          expect(next_start_index).to eq 2
          # next thumbnail to display will be the third VIEWABLE member, namely asset 5.
          expect(viewable_members[next_start_index].friendlier_id).to eq asset5.friendlier_id
        end
      end
      it "does show unpublished assets to a logged-in user", logged_in_user: :admin do
        render_inline described_class.new(work, members_per_batch: 3)
        expect(hero_friendlier_id).to eq(asset1.friendlier_id)
        expect(other_thumbs_friendlier_id_list).to eq [ asset2.friendlier_id, asset3.friendlier_id ]
        expect(page.first('*[data-trigger="lazy-member-images"]')['data-start-index']).to eq "3"
      end
    end

    context "work with a child work" do
      #replace asset2, in position 1, with a child work:
      let(:asset2) { nil }
      let(:child_work) { create(:work, :published, position: 1) }
      let(:members) {[asset1, child_work, asset3, asset4, asset5]}
      it "unpublished assets are counted towards the images-per-page total" do
        render_inline described_class.new(work, members_per_batch: 4)
        expect(hero_friendlier_id).to eq(asset1.friendlier_id)
        expect(other_thumbs_friendlier_id_list).to eq [
          child_work.friendlier_id,
          asset3.friendlier_id,
          asset4.friendlier_id
        ]
        # The next batch of assets fetched will start with the fifth asset:
        expect(page.first('*[data-trigger="lazy-member-images"]')['data-start-index']).to eq "4"
      end
    end
  end
end
