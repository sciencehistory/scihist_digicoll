require 'rails_helper'

describe MemberPreviousAndNextGetter, type: :model do
  let(:members) { parent_work.members.order(:position, :id) }
  
  let(:result) do
    members.map do |m|
      getter = MemberPreviousAndNextGetter.new(m)
      [ getter.previous_model&.id, getter.next_model&.id ]
    end
  end

  let(:expected_result) do
    [
      [ nil,           members[1].id ],
      [ members[0].id, members[2].id ],
      [ members[1].id, members[3].id ],
      [ members[2].id, members[4].id ],
      [ members[3].id, nil           ]
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
