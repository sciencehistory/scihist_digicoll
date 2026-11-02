FactoryBot.define do
  factory :patron, class: Patron do
    sequence(:email) { |n| "patron#{n}@example.com" }
    name { "Test Patron" }
  end
end
