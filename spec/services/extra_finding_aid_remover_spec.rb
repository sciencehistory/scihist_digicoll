require 'rails_helper'

# See https://github.com/sciencehistory/scihist_digicoll/pull/2726 for context.

# This test is for code that will be run only once:
# lib/tasks/remove_extra_finding_aids.rake

# We will need to delete it after we run this code.

describe ExtraFindingAidRemover, queue_adapter: :test do

  let(:link_array_1) {[RelatedLink.new(category: 'finding_aid', url: 'https://archives.sciencehistory.org/repositories/3/resources/1')]}
  let(:link_array_2) {[RelatedLink.new(category: 'finding_aid', url: 'https://archives.sciencehistory.org/repositories/3/resources/2')]}
  let(:link_array_with_non_fa_link) {[RelatedLink.new(category: 'institute_video', url: 'https://example.com/some_thing')]}


  let(:collection) { create(:collection, related_link: link_array_1 ) }
  let(:work)       { create(:public_work, contained_by: [collection], related_link: link_array_1    ) }
  let(:child_work) { create(:public_work, parent: work, related_link: link_array_1) }

  describe "regular work, no collection" do
    let(:work) { create(:public_work, related_link: link_array_1    ) }
    it "does nothing" do
      expect(work.related_link.length).to eq 1
      ExtraFindingAidRemover.new(work).process
      expect(work.reload.related_link).to eq link_array_1
    end
  end

  describe "regular work, duplicates collection's FA" do
    it "removes work FA" do
      expect(work.related_link.length).to eq 1
      ExtraFindingAidRemover.new(work).process
      expect(work.reload.related_link).to eq []
    end
  end

  describe "child work, duplicates parent work's FA" do
    it "deletes child work's FA" do
      expect(child_work.related_link.length).to eq 1
      ExtraFindingAidRemover.new(child_work).process
      expect(child_work.reload.related_link).to eq []
    end
  end

  describe "regular work, no collection or FA" do
    let(:work) { create(:public_work, related_link: link_array_1 ) }
    it "does nothing" do
      expect(work.related_link.length).to eq 1
      ExtraFindingAidRemover.new(work).process
      expect(work.reload.related_link).to eq link_array_1
    end
  end

  describe "regular work, two finding aids, the first of which is a dupe" do
    let(:work) { create(:public_work, related_link: (link_array_1 + link_array_2), contained_by: [collection] ) }
    it "removes first FA" do
      ExtraFindingAidRemover.new(work).process
      expect(work.reload.related_link).to eq link_array_2
    end
  end


  describe "non-finding-aid link" do
    let(:work) { create(:public_work, related_link: (link_array_1 + link_array_2 + link_array_with_non_fa_link), contained_by: [collection] ) }
    it "removes what it should remove, ignores the non-finding aid link" do
      ExtraFindingAidRemover.new(work).process
      expect(work.reload.related_link).to eq(link_array_2 + link_array_with_non_fa_link)
    end
  end



end
