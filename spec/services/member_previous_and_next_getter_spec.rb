require 'rails_helper'

describe MemberPreviousAndNextGetter, type: :model do
  let(:members) { parent_work.members.order(:position, :id) }

  # friendlier_ids
  let(:actual_ids) do
    members.map do |m|
      getter = MemberPreviousAndNextGetter.new(m)
      [ getter&.previous_friendlier_id, getter&.next_friendlier_id ]
    end
  end
  let(:expected_ids) do
    [
      [ nil,                      members[1].friendlier_id ],
      [ members[0].friendlier_id, members[2].friendlier_id ],
      [ members[1].friendlier_id, members[3].friendlier_id ],
      [ members[2].friendlier_id, members[4].friendlier_id ],
      [ members[3].friendlier_id, nil           ]
    ]
  end

  # 'Asset' or 'Work'
  let(:actual_types) do
    members.map do |m|
      getter = MemberPreviousAndNextGetter.new(m)
      [ getter&.previous_type, getter&.next_type ]
    end
  end
  let(:expected_types) do
    [
      [ nil,             members[1].type ],
      [ members[0].type, members[2].type ],
      [ members[1].type, members[3].type ],
      [ members[2].type, members[4].type ],
      [ members[3].type, nil           ]
    ]
  end

  describe "navigation between members of a parent work" do
    context "four assets and one child work" do
      let(:parent_work) { FactoryBot.create(:work, :with_assets, asset_count: 4) }
      let!(:child_work) { FactoryBot.create(:work, :with_assets, parent: parent_work, position: 5) }
      it "finds previous and next members correctly" do
        expect(actual_types).to eq(expected_types)
        expect(actual_ids).to eq(expected_ids)
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
        expect(actual_types).to eq(expected_types)
        expect(actual_ids).to eq(expected_ids)
      end
    end

    context "parent_work is absent" do
      let(:members) {[
        FactoryBot.create(:asset),
        FactoryBot.create(:asset),
      ]}
      it "doesn't throw an error" do
        expect(actual_types).to eq([[nil, nil], [nil, nil]])
        expect(actual_ids).to   eq([[nil, nil], [nil, nil]])
      end
    end
  end
end
