FactoryBot.define do
  factory :r_and_r_item, class: Admin::RAndRItem do
    title { 'Some Item' }
    curator { 'ashley' }
    patron_name { 'Testy McTester' }
    patron_email { 'test@test.org' }
    bib_number { 'b1234567' }
    is_destined_for_ingest { true }
    deadline { '2021-01-10 12:00:00'}
    date_files_sent { '2021-01-09 11:00:00'}
    copyright_status { "Unclear"}
    collecting_area { Admin::RAndRItem::COLLECTING_AREAS.first}
  end
end