FactoryBot.define do
  factory :r_and_r_item, class: Admin::RAndRItem do
    title { 'Some Item' }

    curator { 'ashley' }
    collecting_area { Admin::RAndRItem::COLLECTING_AREAS.first}
    patron_name { 'Testy McTester' }
    patron_email { 'test@test.org' }

    bib_number { 'b1234567' }
    location { 'location' }
    accession_number { '1234567' }
    museum_object_id { '12345' }
    box {'box'}
    folder {'folder'}
    dimensions {'dimensions'}
    materials {'materials'}
    copyright_status { "Unclear"}

    is_destined_for_ingest { true }
    copyright_research_still_needed { true }
    instructions {'instructions'}
    scope {'scope'}
    additional_pages_to_ingest {'additional pages to ingest'}
    additional_notes {'additional notes'}

    status {'awaiting_dig_on_cart'}
    status_changed_at { '2020-01-09 11:00:00'}
    deadline { '2021-01-10 12:00:00'}
    date_files_sent { '2021-01-09 11:00:00'}
  end
end