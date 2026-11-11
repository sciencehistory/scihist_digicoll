FactoryBot.define do
  factory :patron, class: Patron do
    sequence(:email) { |n| "patron#{n}@example.com" }
    name { "Test Patron" }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end
