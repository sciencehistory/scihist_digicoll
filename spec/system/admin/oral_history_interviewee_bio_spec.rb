require 'rails_helper'

RSpec.describe "Oral History Access Request Administration", :logged_in_user, type: :system, queue_adapter: :test  do
  let(:preview_pdf) { create(:asset_with_faked_file, :pdf, published: true) }
  let(:protected_pdf) { create(:asset_with_faked_file, :pdf, published: false, oh_available_by_request: true) }
  let(:protected_mp3) { create(:asset_with_faked_file, :mp3, published: false, oh_available_by_request: true) }

  let (:date) { [
        OralHistoryContent::IntervieweeDate.new(date: '1923', category:'birth', place: 'poland',  ),
        OralHistoryContent::IntervieweeDate.new(date: '2223', category: 'death', place: 'finland' )
      ] }
  let (:school) { [
        OralHistoryContent::IntervieweeSchool.new(date: "1958", institution: 'Columbia University', degree: 'BA', discipline: 'Chemistry'),
        OralHistoryContent::IntervieweeSchool.new(date: "1960", institution: 'Harvard University',  degree: 'MS', discipline: 'Physics')
      ] }
  let (:job) { [
        OralHistoryContent::IntervieweeJob.new({start: "1962", end: "1965", institution: 'Harvard University',  role: 'Junior Fellow, Society of Fellows'}),
        OralHistoryContent::IntervieweeJob.new( {start: "1965", end: "1968",  institution: 'Cornell University', role: 'Associate Professor, Chemistry'})
      ] }
  let (:honor) { [
        OralHistoryContent::IntervieweeHonor.new(date: "1981", honor: 'Nobel Prize in Chemistry'),
        OralHistoryContent::IntervieweeHonor.new(date: "1998", honor: 'Corresponding Member, Nordrhein-Westfälische Academy of Sciences')
      ] }


  let!(:work) do
    create(:oral_history_work, published: true).tap do |work|
      work.members << preview_pdf
      work.members << protected_pdf
      work.members << protected_mp3

      work.representative =  preview_pdf

      work.oral_history_content!.update(interviewee_date:   date)
      work.oral_history_content!.update(interviewee_school: school)
      work.oral_history_content!.update(interviewee_job:    job)
      work.oral_history_content!.update(interviewee_honor:  honor)

      work.save!
    end
  end


  context "A request exists for a manual_review work" do
    let!(:oh_request) { Admin::OralHistoryAccessRequest.create!(
      patron_name: "George Washington Carver",
      patron_email: "george@example.org",
      patron_institution: "Tuskegee Institute",
      intended_use: "Recreational reading.",
      work: work
    )}

    it "interviewee bio data shows up" do
      visit admin_work_path(work, :anchor => "nav-oral-histories-bio")
      # to be continued ...
    end
  end
end
