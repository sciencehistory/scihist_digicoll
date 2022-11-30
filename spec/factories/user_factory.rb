FactoryBot.define do
  factory :user, class: User do
    email { "no-reply@sciencehistory.org"}

    factory :admin_user do
      user_type { "admin" }
    end
  end
end
