FactoryBot.define do
  factory :collection, class: Collection do
    title { 'Test title' }
    description { "Test collection description" }
    related_url { ["http://example.com"] }
    department { "Archives" }
    published { true }
  end
end
