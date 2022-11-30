FactoryBot.define do
  factory :user, class: User do
    email { "no-reply@sciencehistory.org"}

    factory :admin_user do
      user_type { "admin" }
    end

    factory :editor_user do
      user_type { "editor" }
    end
  end
end
