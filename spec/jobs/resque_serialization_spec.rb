require 'rails_helper'

# Our test and dev environments don't use the Resque adapter, so nothing else exercises
# Resque's own JSON encode/decode. In Nov 2026 json 3.x broke MultiJson.load, and production
# workers silently dropped every job they popped. This spec catches that kind of breakage.
describe "Resque job serialization" do
  it "round-trips an ActiveJob payload through Resque.encode and Resque.decode" do
    job = ActionMailer::MailDeliveryJob.new("OralHistoryDeliveryMailer", "approved_with_session_link_email", "deliver_now", args: [])
    payload = { "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper", "args" => [job.serialize] }

    expect(Resque.decode(Resque.encode(payload))).to eq(payload)
  end
end
