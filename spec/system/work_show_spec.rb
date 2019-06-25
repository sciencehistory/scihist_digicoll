require 'rails_helper'

describe "Public work show page", type: :system do

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


    let(:work) { create(:work, :with_complete_metadata, parent: create(:work)) }

    # REALLY doesn't test everything, just a sampling
    it "smoke tests" do
      visit work_path(work)

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

      expect_attribute_row("Subject", work.subject, as_links: true)
      expect_attribute_row("Rights", RightsTerms.label_for(work.rights), as_links: true)

      expect_attribute_row("Department", work.department, as_links: true)
      expect_attribute_row("Exhibition", work.exhibition, as_links: true)
      expect_attribute_row("Project", work.project, as_links: true)
      expect_attribute_row("Series arrangement", work.series_arrangement)

      expect_attribute_row("Physical container", work.physical_container.display_as)
    end
  end
end
