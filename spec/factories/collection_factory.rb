FactoryBot.define do
  factory :collection, class: Collection do
    title { 'Test title' }
    description { "Test collection description" }
    related_url { ["http://example.com"] }
    related_link {
      [
        {
          url: "https://sciencehistory.org/some_biography",
          category: "institute_biography",
          label: "Joe Schmoe"
        }
      ]
    }
    department { "Archives" }
    published { true }
  end
end
