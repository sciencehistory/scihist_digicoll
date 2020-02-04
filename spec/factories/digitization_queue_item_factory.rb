FactoryBot.define do
  factory :digitization_queue_item, class: Admin::DigitizationQueueItem do
    title { 'Some Item' }
    collecting_area { "archives" }
    accession_number { '2008.064' }
  end
end
