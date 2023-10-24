require 'rails_helper'

describe MemberPreviousAndNextGetter, type: :model do
  let(:members) { parent_work.members.order(:position, :id) }

  let(:actual_urls) do
    members.map do |m|
      getter = MemberPreviousAndNextGetter.new(m)
      [ getter&.previous_url, getter&.next_url ]
    end  
  end

  let(:wrk_prefix) { "/admin/works/" }
  let(:ast_prefix) { "/admin/asset_files/" }

  describe "navigation between members of a parent work" do
    context "four assets and one child work" do
      let(:parent_work) { FactoryBot.create(:work, :with_assets, asset_count: 4) }
      let!(:child_work) { FactoryBot.create(:work, :with_assets, parent: parent_work, position: 5) }
      it "finds previous and next members correctly" do
        expect(actual_urls).to eq ([
          [ nil,
            "#{ast_prefix}#{members[1].friendlier_id}"],

          [ "#{ast_prefix}#{members[0].friendlier_id}",
            "#{ast_prefix}#{members[2].friendlier_id}"],

          [ "#{ast_prefix}#{members[1].friendlier_id}",
            "#{ast_prefix}#{members[3].friendlier_id}"],

          [ "#{ast_prefix}#{members[2].friendlier_id}",
            "#{wrk_prefix}#{members[4].friendlier_id}"],

          [ "#{ast_prefix}#{members[3].friendlier_id}",
            nil]
        ])
      end
    end

    context "non-consecutive, duplicate and nil positions" do
      let (:basic_uuid) {'00000000-0000-4000-8000-%012x'}
      let!(:parent_work) { FactoryBot.create(:work, members: [
        FactoryBot.create(:asset, id: basic_uuid % 1, position: nil),
        FactoryBot.create(:asset, id: basic_uuid % 2, position: 7  ),
        FactoryBot.create(:asset, id: basic_uuid % 3, position: 29 ),
        FactoryBot.create(:work,  id: basic_uuid % 4, position: nil),
        FactoryBot.create(:work,  id: basic_uuid % 5, position: 7  )
        ] )
      }
      it "finds previous and next members correctly" do
        expect(actual_urls).to eq ([
          [ nil,
            "#{wrk_prefix}#{members[1].friendlier_id}"],

          [ "#{ast_prefix}#{members[0].friendlier_id}",
            "#{ast_prefix}#{members[2].friendlier_id}"],

          [ "#{wrk_prefix}#{members[1].friendlier_id}",
            "#{ast_prefix}#{members[3].friendlier_id}"],

          [ "#{ast_prefix}#{members[2].friendlier_id}",
            "#{wrk_prefix}#{members[4].friendlier_id}"],

          [ "#{ast_prefix}#{members[3].friendlier_id}",
            nil]
        ])
      end
    end

    context "parent_work is absent" do
      let(:members) {[
        FactoryBot.create(:asset),
        FactoryBot.create(:asset),
      ]}
      it "doesn't throw an error" do
        expect(actual_urls).to eq([[nil, nil], [nil, nil]])
      end
    end
  end
end
