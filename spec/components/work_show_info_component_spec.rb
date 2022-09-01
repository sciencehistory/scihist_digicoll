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
end
