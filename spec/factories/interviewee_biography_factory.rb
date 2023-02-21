FactoryBot.define do
  factory :interviewee_biography, class: IntervieweeBiography do
    name { "Smith, John"}

    birth { OralHistoryContent::DateAndPlace.new(date: '1923', city: 'Place of Birth', state: 'CA', country: 'US') }

    death { OralHistoryContent::DateAndPlace.new(date: '2223', city: 'Place of Death', province: 'NU', country: 'CA' ) }

    school {[
      OralHistoryContent::IntervieweeSchool.new(date: "1958", institution: 'Columbia University', degree: 'BA', discipline: 'Chemistry'),
      OralHistoryContent::IntervieweeSchool.new(date: "1960", institution: 'Harvard University',  degree: 'MS', discipline: 'Physics')
    ]}

    job {[
      OralHistoryContent::IntervieweeJob.new({start: "1962", end: "1965", institution: 'Harvard University',  role: 'Junior Fellow, Society of Fellows'}),
      OralHistoryContent::IntervieweeJob.new( {start: "1965", end: "1968",  institution: 'Cornell University', role: 'Associate Professor, Chemistry'}),
      OralHistoryContent::IntervieweeJob.new( {start: "2012", end: "present",  institution: 'Princeton University', role: 'Professor, Chemistry'})
    ]}

    honor {[
      OralHistoryContent::IntervieweeHonor.new(start_date: "1981", honor: 'Nobel Prize in Chemistry'),
      OralHistoryContent::IntervieweeHonor.new(start_date: "1998", honor: 'Corresponding Member, Nordrhein-Westfälische Academy of Sciences')
    ]}
  end
end
