require 'rails_helper'
require "#{Rails.root}/lib/scihist_digicoll/task_helpers/related_url_updater"

describe ScihistDigicoll::TaskHelpers::RelatedUrlUpdater, type: :model do
  let(:updater) { ScihistDigicoll::TaskHelpers::RelatedUrlUpdater.new }

  let(:work_to_update) do 
    create(:public_work, related_url: [
      'https://archives.sciencehistory.org/2019-011.html',
      'https://archives.sciencehistory.org/2012-002.html'
    ])
  end

  it "updates related URLs" do
    updater.process_work(work_to_update)
    work_to_update.reload
    expect(work_to_update.related_url).to eq [
      "https://archives.sciencehistory.org/repositories/3/resources/86",
      "https://archives.sciencehistory.org/repositories/3/resources/1"
    ]
 end
end