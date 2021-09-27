require 'rails_helper'


describe "Public work show page", type: :system, js: false do

  describe "work with complete metadata" do
    def expect_attribute_row(header, text_values, as_links: false)
      text_values = Array.wrap(text_values)
      header = page.first("th", text: header)
      row = header.first(:xpath,".//..")
      td = row.first("td")

      text_values.each do |value|
        if as_links
          expect(td).to have_link(value)
        else
          expect(td).to have_selector("li", text: value)
        end
      end
    end


    let(:work) {
      create(
        :work, :published, :with_complete_metadata, contained_by: [create(:collection)], parent: create(:work, :published), members: [
          create(:asset_with_faked_file,
            title: "First asset (representative)",
            faked_derivatives: {},
            position: 0),
          create(:asset_with_faked_file,
            title: "Second asset",
            faked_derivatives: {},
            position: 1),
          create(:asset_with_faked_file,
            title: "Third asset (private)",
            faked_derivatives: {},
            published: false,
            position: 2)
          ]
      )
    }

    before do
      work.representative = work.members.first
      work.save!
    end


    # REALLY doesn't test everything, just a sampling
    it "smoke tests" do
      visit work_path(work)

      # Don't show the edit button to users unless they're logged in.
      expect(page).to have_no_css('a', text: "Edit")

      # No audio assets, so the playlist should not be present.
      expect(page.find_all(".show-page-audio-playlist-wrapper").count). to eq 0

      thumbnails = page.find_all('.member-image-presentation')
      expect(thumbnails.count). to eq work.members.select {|m| m.published }.count


      within(".show-genre") do
        work.genre.each do |g|
          expect(page).to have_link(g)
        end
      end

      expect(page).to have_selector("h1", text: work.title)

      within(".additional-titles") do
        work.additional_title.each do |title|
          expect(page).to have_selector("h2", text: title)
        end
      end

      within(".part-of") do
        expect(page).to have_selector("li", text: "Part of #{work.source}")
        expect(page).to have_link(work.parent.title)
      end

      within(".show-date") do
        expect(page).to have_selector("li", count: work.date_of_work.count)
      end

      within(".work-description") do
        expect(page).to have_selector("p", text: /#{Regexp.escape(work.description.slice(0, 10))}/)
      end

      work.creator.each do |creator|
        attribute_header = page.first("th", text: creator.category.humanize)
        attribute_row = attribute_header.first(:xpath,".//..")
        expect(attribute_row).to have_link(creator.value)
      end

      expect(page).to have_selector("th", text: "Provenance")

      work.place.each do |creator|
        attribute_header = page.first("th", text: creator.category.humanize)
        attribute_row = attribute_header.first(:xpath,".//..")
        expect(attribute_row).to have_link(creator.value)
      end

      expect_attribute_row("Genre", work.genre, as_links: true)
      expect_attribute_row("Medium", work.medium)
      expect_attribute_row("Extent", work.extent)
      expect_attribute_row("Language", work.language, as_links: true)

      expect_attribute_row("Inscription", work.inscription.map(&:display_as))
      expect_attribute_row("Digitization funder", work.digitization_funder)
      expect_attribute_row("Subject", work.subject, as_links: true)
      expect_attribute_row("Rights", RightsTerms.label_for(work.rights), as_links: true)

      expect_attribute_row("Department", work.department, as_links: true)
      expect_attribute_row("Exhibition", work.exhibition, as_links: true)
      expect_attribute_row("Project", work.project, as_links: true)
      expect_attribute_row("Series arrangement", work.series_arrangement)

      expect_attribute_row("Physical container", work.physical_container.display_as)
    end
  end

  describe "work with very little metadata" do
    let(:work) { create(:work, :published) }
    it "displays without error" do
      visit work_path(work)
      expect(page).to have_http_status(:success)
      expect(page).to have_selector("h1", text: work.title)
    end
  end

  describe "Multi-page work with transcription and translation", js: true do
    let(:work) do
      create(:public_work, :with_complete_metadata,
        members: [
          create(:asset_with_faked_file, position: 1, transcription: "This is file-1 transcription", english_translation: "This is file-1 translation"),
          create(:asset_with_faked_file, position: 2, transcription: "This is file-2 transcription", english_translation: "This is file-2 translation")
        ]
      )
    end

    it "displays transcription and translation in tabs" do
      visit work_path(work)

      # if we are in small screen menu, we need to click on currently selected tab to open menu first!
      click_on "Description"
      click_on "Transcription"

      expect(page).to have_text(/IMAGE 1.*This is file-1 transcription.*IMAGE 2.*This is file-2 transcription/m)
      expect(page).not_to have_text("This is file-1 translation")
      expect(page).not_to have_text("This is file-2 translation")

      expect(page).to have_link(text: "IMAGE 1", href: viewer_path(work, work.members.first.friendlier_id))
      expect(page).to have_link(text: "IMAGE 2", href: viewer_path(work, work.members.second.friendlier_id))

      # if we are in small screen menu, we need to click on currently selected tab to open menu first!
      click_on "Transcription"
      click_on "English Translation"

      expect(page).to have_text(/IMAGE 1.*This is file-1 translation.*IMAGE 2.*This is file-2 translation/m)
      expect(page).not_to have_text("This is file-1 transcription")
      expect(page).not_to have_text("This is file-2 transcription")

      expect(page).to have_link(text: "IMAGE 1", href: viewer_path(work, work.members.first.friendlier_id))
      expect(page).to have_link(text: "IMAGE 2", href: viewer_path(work, work.members.second.friendlier_id))
    end
  end

end

describe "Public work show page", :logged_in_user, type: :system, js: false do
  let(:work) {
    create( :work, :published, members:
      [
        create( :asset_with_faked_file, position: 0, title: "Published asset", published: true  ),
        create( :work, :published, position: 1, title: "First child work", published: true  ),
        create( :work, :published, position: 2, title: "Second child work", published: false ),
        create( :work, :published, position: 3, title: "Third child work", published: true  ),
        create( :asset_with_faked_file,  position: 4, title: "Private asset",  published: false )
      ]
    )
  }

  before do
    work.representative = work.members.first
    work.save!
  end

  describe "Logged in user" do
    it "shows the edit button, and all child items, including unpublished ones." do
      visit work_path(work)
      expect(page.find(:css, 'a[text()="Edit"]').visible?).to be true
      thumbnails = page.find_all('.member-image-presentation')
      expect(thumbnails.count).to eq work.members.count
    end
  end
end
