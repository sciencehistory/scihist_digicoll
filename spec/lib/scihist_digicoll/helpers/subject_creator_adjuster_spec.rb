require 'rails_helper'
require "#{Rails.root}/lib/scihist_digicoll/task_helpers/subject_creator_adjuster"

describe ScihistDigicoll::TaskHelpers::SubjectCreatorAdjuster, type: :model do
  let(:adjuster) { ScihistDigicoll::TaskHelpers::SubjectCreatorAdjuster.new }

  let(:work_to_update) do 
    create(:public_work, creator: [
        Work::Creator.new({category:'author',  value: 'unchanged'}),
        Work::Creator.new({category:'author',  value: 'Bredig, Georg, 1868-'}),
        Work::Creator.new({category:'addressee',value: 'Bredig, Georg, 1868-'})
     ],
     subject: ['as is', 'Caruso, David J.']
     )
  end

  it "updates creators and subjects" do
    adjuster.process_work(work_to_update)
    work_to_update.reload
    expect(work_to_update.creator.map(&:value)).to eq ["unchanged", "Bredig, Georg, 1868-1944", "Bredig, Georg, 1868-1944"]
    expect(work_to_update.subject).to eq ["as is", "Caruso, David J., (David Joseph), 1978-"]
  end
end