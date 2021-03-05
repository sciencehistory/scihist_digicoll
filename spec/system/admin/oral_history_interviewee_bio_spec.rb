require 'rails_helper'

RSpec.describe "Oral History Access Interviewee bio", :logged_in_user, type: :system, queue_adapter: :test  do

  let!(:work) { create(:oral_history_work, published: true) }


  it "interviewee bio data shows up" do
    visit admin_work_path(work, :anchor => "nav-oral-histories")

    interviewee_bio = find("h2", text: "Interviewee bio").ancestor('.card')

    within(interviewee_bio) do

      expect(page).to have_text("Edit")
      expect(page).to have_text("Interviewee biography")
      expect(page).to have_text("Place of Birth, CA, United States of America, 1923")
      expect(page).to have_text("Died: Place of Death, NU, Canada, 2223")
      expect(page).to have_text("MS, Physics, Harvard University")
      expect(page).to have_text("1981: Nobel Prize in Chemistry")
      click_link "Edit"
    end

    honors = find("fieldset.oral_history_content_interviewee_honor")

    click_link "Add another Interviewee honor"
    click_link "Add another Interviewee honor"

    within(honors) do
      within find_all(".nested-fields")[2] do
        fill_in("Date", with: "2234")
        fill_in("Honor", with: "Beatified")
      end
      within find_all(".nested-fields")[3] do
        fill_in("Date", with: "2334-12-34")
        fill_in("Honor", with: "Canonized")
      end
    end
    find('input[name="commit"]').click

    interviewee_bio = find("h2", text: "Interviewee bio").ancestor('.card')
    within(interviewee_bio) do
      expect(page).to have_text("Died: Place of Death, NU, Canada, 2223")
      expect(page).to have_text("2234: Beatified")
      expect(page).to have_text("2334-12-34: Canonized")
      click_link "Edit"
    end
  end

end
