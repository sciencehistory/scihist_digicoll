require 'rails_helper'

describe IntervieweeBiography do
  it "rejects bad dates" do
    bio = IntervieweeBiography.new(birth: { date: 'This is not a correct birth date.'})
    expect{bio.save!}.to raise_error(ActiveRecord::RecordInvalid)

    bio = IntervieweeBiography.new(job: [OralHistoryContent::IntervieweeJob.new(start: 'This is not a correct date either.')])
    expect{bio.save!}.to raise_error(ActiveRecord::RecordInvalid)
  end
end
