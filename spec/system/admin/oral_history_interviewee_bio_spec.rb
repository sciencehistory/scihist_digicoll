require 'rails_helper'
RSpec.describe "Oral History Access Interviewee bio", :logged_in_user, type: :system, queue_adapter: :test  do
  let!(:work) { create(:oral_history_work, published: true) }
  it "interviewee bio data shows up" do
    visit admin_work_path(work, :anchor => "nav-oral-histories")
    interviewee_bio = find("h2", text: "Interviewee biography").ancestor('.card')
    within(interviewee_bio) do
      expect(page).to have_text("Edit")
      expect(page).to have_text("Interviewee biography")
      expect(page).to have_text("1923, Place of Birth, California, United States")
      expect(page).to have_text("Died: 2223, Place of Death, Nunavut, Canada")
      expect(page).to have_text("1962 – 1965: Junior Fellow, Society of Fellows, Harvard University")
      expect(page).to have_text("1965 – 1968: Associate Professor, Chemistry, Cornell University")
      expect(page).to have_text("MS, Physics, Harvard University")
      expect(page).to have_text("1981, Nobel Prize in Chemistry")
      click_link "Edit"
    end


    # Make sure date validation works on at least one of the dates.
    # We assume if one works they all do.
    fill_in('oral_history_content_interviewee_birth_attributes_date', with: '1937-07-1aa')

    find('input[name="commit"]').click
    expect(page).to have_text("Date Must be of format YYYY[-MM-DD]")


    fill_in('oral_history_content_interviewee_birth_attributes_date', with: '')
    fill_in('oral_history_content_interviewee_birth_attributes_city', with: '')
    select '', from: 'oral_history_content_interviewee_birth_attributes_state'
    select '', from: 'oral_history_content_interviewee_birth_attributes_province'
    find_by_id('oral_history_content_interviewee_birth_attributes_country').
      find('option[value=""]').click


    fill_in('oral_history_content_interviewee_death_attributes_date', with: '')
    fill_in('oral_history_content_interviewee_death_attributes_city', with: '')
    select '', from: 'oral_history_content_interviewee_death_attributes_state'
    select '', from: 'oral_history_content_interviewee_death_attributes_province'
    find_by_id('oral_history_content_interviewee_death_attributes_country').
      find('option[value=""]').click


    schools = find("fieldset.oral_history_content_interviewee_school")
    within(schools) do
      find_all('a.remove_fields')[0].click
      find_all('a.remove_fields')[0].click
      click_link "Add another Interviewee school"
      within find_all(".nested-fields")[0] do
        fill_in("Date", with: "1234")
        fill_in("Institution", with: "Columbia University")
        fill_in("Degree", with: "PhD")
        fill_in("Discipline", with: "Physics")
      end
    end

    honors = find("fieldset.oral_history_content_interviewee_honor")
    click_link "Add another Interviewee honor"
    click_link "Add another Interviewee honor"
    within(honors) do
      within find_all(".nested-fields")[2] do
        fill_in("Start", with: "2234")
        fill_in("Honor", with: "honor 1")
      end
      within find_all(".nested-fields")[3] do
        fill_in("Start", with: "2334-12-34")
        fill_in("Honor", with: "honor 2")
      end
    end

    jobs = find("fieldset.oral_history_content_interviewee_job")
    within(jobs) do
      find_all('a.remove_fields')[0].click
      find_all('a.remove_fields')[0].click
      click_link "Add another Interviewee job"
      within find_all(".nested-fields")[0] do
        fill_in("Start", with: "2334-12-34")
        fill_in("End", with: "2334-12-35")
        fill_in("Role", with: "Sotheby's")
        fill_in("Institution", with: "Head Auctioneer")
      end
    end

    find('input[name="commit"]').click

    interviewee_bio = find("h2", text: "Interviewee biography").ancestor('.card')

    within(interviewee_bio) do
      expect(page).to have_text("2234, honor 1")
      expect(page).to have_text("2334-12-34, honor 2")
      expect(page).to have_text("1234: PhD, Physics, Columbia University")
      expect(page).not_to have_text("Place of Birth")
      expect(page).not_to have_text("Died")
    end

    work.reload


    expect(work.oral_history_content.interviewee_birth).to be_nil
    expect(work.oral_history_content.interviewee_death).to be_nil
    expect(work.oral_history_content.interviewee_job.length).to eq 1
    correct_jobs = "{\"end\"=>\"2334-12-35\", \"role\"=>\"Sotheby's\", \"start\"=>\"2334-12-34\", \"institution\"=>\"Head Auctioneer\"}"
    expect(work.oral_history_content.interviewee_job.first.attributes.to_s ).to eq correct_jobs
  end
end
