FactoryBot.define do
  factory :oral_history_request, class: OralHistoryRequest do
    patron { build(:patron, name: patron_name) }
    patron_name { "Emily Torres" }
    work { build(:oral_history_work, :available_by_request) }
    delivery_status { "approved" }
    intended_use { "Just for fun" }
  end
end
