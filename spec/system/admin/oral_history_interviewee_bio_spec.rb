require 'rails_helper'
RSpec.describe "Oral History Access Interviewee bio", :logged_in_user, type: :system, queue_adapter: :test  do
  let(:work) { create(:oral_history_work, :published) }

  it "can add an Interviewee Biography" do
    visit admin_interviewee_biographies_path
    click_on "New Interviewee Biography"

    fill_in "interviewee_biography_name", with: "Eddie Haskell"

    # Make sure date validation works on at least one of the dates.
    # We assume if one works they all do.
    fill_in('interviewee_biography_birth_attributes_date', with: '1937-07-1aa')

    find('input[name="commit"]').click
    expect(page).to have_text("Must be of format YYYY[-MM-DD]")

    fill_in('interviewee_biography_birth_attributes_date', with: '1937-07-01')

    schools = find("fieldset.interviewee_biography_school")
    within(schools) do
      click_link "Add another School"
      within find_all(".nested-fields")[0] do
        fill_in("Date", with: "1234")
        fill_in("Institution", with: "Columbia University")
        fill_in("Degree", with: "PhD")
        fill_in("Discipline", with: "Physics")
      end
    end

    honors = find("fieldset.interviewee_biography_honor")
    click_link "Add another Honor"
    click_link "Add another Honor"
    within(honors) do
      within find_all(".nested-fields")[1] do
        fill_in("Start", with: "2234")
        fill_in("Honor", with: "honor 1")
      end
      within find_all(".nested-fields")[2] do
        fill_in("Start", with: "2334-12-34")
        fill_in("Honor", with: "honor 2")
      end
    end

    jobs = find("fieldset.interviewee_biography_job")
    within(jobs) do
      click_link "Add another Job"
      within find_all(".nested-fields")[0] do
        fill_in("Start", with: "2334-12-34")
        fill_in("End", with: "2334-12-35")
        fill_in("Role", with: "Sotheby's")
        fill_in("Institution", with: "Head Auctioneer")
      end
    end

    find('input[name="commit"]').click

    expect(page).to have_selector("h1", text: "Oral History: Interviewee Biographies")

    biography = IntervieweeBiography.last

    expect(biography).to be_present
    expect(biography.birth.date).to eq("1937-07-01")

    expect(biography.job.length).to eq 1

    correct_job = {"end" => "2334-12-35", "role" => "Sotheby's", "start" => "2334-12-34", "institution" => "Head Auctioneer"}
    expect(biography.job.first.attributes).to eq correct_job
  end

  it "interviewee bio data shows up linked" do
    visit admin_work_path(work, :anchor => "tab=nav-oral-histories")
    section = find("h2", text: "Interviewee biography").ancestor('.card')
    within(section) do
      # have to find hidden select, since it's covered by tom-select.js UI
      expect(find("select", visible: :all).value).to match_array(work.oral_history_content.interviewee_biographies.collect(&:id).collect(&:to_s))
    end
  end
end
