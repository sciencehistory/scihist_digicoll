FactoryBot.define do
  factory :digitization_queue_item, class: Admin::DigitizationQueueItem do
    title { 'Some Item' }
    collecting_area { Admin::DigitizationQueueItem::COLLECTING_AREAS.first}
  end
end
