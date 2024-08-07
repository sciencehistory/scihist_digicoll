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

  context "Collection finding aids for archives works" do
    let(:coll_finding_aid) { RelatedLink.new(category: "finding_aid", url: "https://example.com/coll")}
    let(:work_finding_aid) { RelatedLink.new(category: "finding_aid", url: "https://example.com/work")}
    let!(:other_related_link)  { RelatedLink.new(category: "other_external", url: "https://example.com/other")}

    let(:collection) { build(:collection, related_link: [coll_finding_aid, work_finding_aid ]) }
    let(:work) { create(:public_work, :with_complete_metadata,
      contained_by: [collection], related_link: [work_finding_aid, other_related_link]
    )}

    it "lists finding aid attached directly to the work as well as finding aid attached to the collection" do
      component = WorkShowInfoComponent.new(work: work)
      expect(component.links_to_finding_aids.to_a.sort).to eq([coll_finding_aid.url, work_finding_aid.url])
    end

    context "child work" do
      let (:child) { create(:public_work, parent: work, title: "child") }
      it "checks the parent work and its collection" do
        component = WorkShowInfoComponent.new(work: child)
        expect(component.links_to_finding_aids.to_a.sort).to eq([coll_finding_aid.url, work_finding_aid.url])
      end
    end
  end
end
