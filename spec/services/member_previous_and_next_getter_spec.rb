require 'rails_helper'

describe MemberPreviousAndNextGetter, type: :model do
  let(:result) do
    parent_work.members.order(:position).map do |m|
      getter = MemberPreviousAndNextGetter.new(m)
      {
         previous: getter.previous_model,
         next:     getter.next_model
      }
    end
  end
  let(:members) { parent_work.members.order(:position, :id)}
  let(:expected_result) do
    [
      { previous:nil,         next: members[1] },
      { previous: members[0], next: members[2] },
      { previous: members[1], next: members[3] },
      { previous: members[2], next: members[4] },
      { previous: members[3], next: nil        }
    ]
  end

  describe "navigation between members of a parent work" do
    context "three assets and one child work" do
      let(:parent_work) { FactoryBot.create(:work, :with_assets, asset_count: 4) }
      let!(:child_work) { FactoryBot.create(:work, :with_assets, parent: parent_work, position: 5) }
      it "finds previous and next members correctly" do
        expect(result).to eq(expected_result)
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
        expect(result).to eq expected_result
      end
    end
  end
end
