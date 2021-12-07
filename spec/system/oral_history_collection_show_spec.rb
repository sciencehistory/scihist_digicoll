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
        # We will assign some that will show up on front page in counts
        #
        create(:oral_history_work, :published,
          title: "public work one",
          date_of_work: Work::DateOfWork.new(start: "2019"),
          subject: ["Nobel Prize winners"],
          contained_by: [col])
      end
    end

    let(:project) do
      create(:collection, title: "Nanotechnology",
        friendlier_id: CollectionShowControllers::OralHistoryCollectionController::NANOTECHNOLOGY_FRIENDLIER_ID,
        description: "This is nanotechnology",
        contains: [create(:oral_history_work, :published)])
    end

    it "displays" do
      project # trigger lazy creation
      visit collection_path(collection)

      expect(page).to have_selector("h1", text: collection.title)

      expect(page).to have_selector("a.q", text: /1\s+Nobel Prize winners/)

      expect(page).to have_selector(".project", text: /1\s+Nanotechnology/)
    end

    it "searches" do
      visit collection_path(collection, q: "")

      # has a facet specifically confiured just for oral history collection,
      # as a way of confirming we're using the OralHistoryCollectionController
      expect(page).to have_selector("h3.facet-field-heading", text: "Interviewer")
    end
  end
end
