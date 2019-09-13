FactoryBot.define do
  factory :fixity_check, class: FixityCheck do
    actual_result { "fake_actual_digest" }
    expected_result { "fake_expected_digest" }
    hash_function { "SHA-512" }
    checked_uri { "http://example.com/fake/location" }
    passed { false }
  end
end
