require 'rails_helper'

describe IntervieweeBiography do
  let(:old_job) {OralHistoryContent::IntervieweeJob.new({
    start: "1962", end: "1965",
    institution: 'Harvard University',
    role: 'Junior Fellow, Society of Fellows'})}
  let(:current_job) {OralHistoryContent::IntervieweeJob.new({
    start: "1962", end: "present",
    institution: 'Harvard University',
    role: 'Junior Fellow, Society of Fellows'})}
  let(:bad_job) { OralHistoryContent::IntervieweeJob.new({
    start: "No good", end: "1965",
    institution: 'Harvard University',
    role: 'Junior Fellow, Society of Fellows'})}

  let(:bio_standard)    { create(:interviewee_biography) }
  let(:bio_old_job)     { create(:interviewee_biography, job: [old_job ]) }
  let(:bio_current_job) { create(:interviewee_biography, job: [current_job]) }

  let(:bio_bad_birth_date) { create(:interviewee_biography, birth: { date: 'This is not a correct birth date.'}) }
  let(:bio_bad_job) { create(:interviewee_biography, job: [bad_job]) }

  it "accepts jobs valid jobs" do
    expect{bio_standard.save!}.not_to    raise_error
    expect{bio_old_job.save!}.not_to     raise_error
    expect{bio_current_job.save!}.not_to raise_error
  end

  it "rejects bad dates for birth and job" do
    expect{bio_bad_birth_date.save!}.to raise_error(ActiveRecord::RecordInvalid)
    expect{bio_bad_job.save!}.to        raise_error(ActiveRecord::RecordInvalid)
  end
end
