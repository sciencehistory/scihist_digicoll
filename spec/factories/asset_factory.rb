FactoryBot.define do
  factory :asset, class: Asset do
    title { 'Test title' }

    trait :inline_promoted_file do
      file { File.open((Rails.root + "spec/test_support/images/30x30.png")) }
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(promote: :inline, create_derivatives: :inline)
      end
    end

    trait :no_derivatives_creation do
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(create_derivatives: false)
      end
    end
  end
end
