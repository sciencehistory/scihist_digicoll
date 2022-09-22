FactoryBot.define do
  factory :collection, class: Collection do
    title { 'Test title' }
    description { "Test collection description" }
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

    trait :with_representative do
      representative { build(:asset, :inline_promoted_file, published: true) }
    end
  end
end
