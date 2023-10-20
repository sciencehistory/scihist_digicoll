require 'rails_helper'

describe MemberPreviousAndNextGetter, type: :model do
  let(:result) do
    parent_work.members.order(:position).map do |m|
      getter = MemberPreviousAndNextGetter.new(m)
      {
         previous: getter.previous_model&.id,
         next:     getter.next_model&.id
      }
    end
  end
  let(:expected_result) do
    members = parent_work.reload.members.order(:position, :id)
    [
      { previous: nil,           next: members[1].id },
      { previous: members[0].id, next: members[2].id },
      { previous: members[1].id, next: members[3].id },
      { previous: members[2].id, next: members[4].id },
      { previous: members[3].id, next: nil           }
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
        pp result

        pp expected_result

        expect(result[0]).to eq expected_result[0]
        expect(result[1]).to eq expected_result[1]
        expect(result[2]).to eq expected_result[2]
        expect(result[3]).to eq expected_result[3]
        expect(result[4]).to eq expected_result[4]
      end
    end
  end
end
