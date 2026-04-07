FactoryBot.define do
  factory :studio do
    sequence(:email) { |n| "studio#{n}@example.com" }
    password { "password123" }
    studio_name { "Test Studio" }
    phone { "+1234567890" }
    plan { "free" }
  end
end
