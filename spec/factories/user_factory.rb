FactoryBot.define do
  factory :user, class: User do
    email { "no-reply@sciencehistory.org"}

    factory :admin_user do
      admin { true }
    end
  end
end
