require 'rails_helper'

describe WorkShowInfoComponent, type: :component do
  context "Oral History Number" do
    let(:work) {
      build(:oral_history_work, external_id: [
          {'category' => 'bib', 'value' => 'b1043559'},
          {'category' => 'interview', 'value' => '0012'}
      ])
    }

    it "displays oral history number" do
      render_inline WorkShowInfoComponent.new(work: work)
      expect(page).to have_text(/Oral history number\s+0012/)
    end
  end

  context "exhibitions and collections" do
    let(:exhibition) { build(:collection, department: Collection::DEPARTMENT_EXHIBITION_VALUE) }
    let(:collection) { build(:collection) }
    let(:work) { create(:public_work, :with_complete_metadata, contained_by: [exhibition, collection])}

    it "displays exhibition separately" do
      rendered = render_inline WorkShowInfoComponent.new(work: work)

      expect(page).to have_text(/Collection\s+#{collection.title}/)
      expect(page).to have_text(/Exhibited in\s+#{exhibition.title}/)
    end
  end
end
