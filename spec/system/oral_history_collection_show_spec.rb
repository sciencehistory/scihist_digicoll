require 'rails_helper'

describe "Collection show page", solr: true, indexable_callbacks: true do
  describe "smoke test" do
    let(:collection) do
      create(:collection,
        description: "Oral History Collection",
        friendlier_id: ScihistDigicoll::Env.lookup!(:oral_history_collection_id)
      ).tap do |col|
        # doing these as separate creates after collection exists necessary for them to have collection
        # on save, so to get indexed properly
        #
        create(:oral_history_work, published: true, title: "public work one", date_of_work: Work::DateOfWork.new(start: "2019"), contained_by: [col])
        create(:oral_history_work, published: true, title: "public work two", date_of_work: Work::DateOfWork.new(start: "1900"), contained_by: [col])
      end
    end

    it "displays" do
      visit collection_path(collection)

      expect(page).to have_selector("h1", text: collection.title)

      # has a facet specifically confiured just for oral history collection,
      # as a way of confirming we're using the OralHistoryCollectionController
      expect(page).to have_selector("h3.facet-field-heading", text: "Interviewer")
    end
  end
end
