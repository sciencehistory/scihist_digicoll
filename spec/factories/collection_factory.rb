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
    admin_note { ['admin note', 'second admin note']}
    department { "Archives" }
    published { true }

    trait :with_representative do
      representative { build(:asset_with_faked_file, published: true) }
    end
  end
end
