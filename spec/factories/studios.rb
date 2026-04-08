FactoryBot.define do
  factory :studio do
    sequence(:email) { |n| "studio#{n}-#{SecureRandom.hex(4)}@example.com" }
    password { "password123" }
    studio_name { "Test Studio" }
    phone { "+1234567890" }
    plan { "free" }
    color_primary { "#1a1a1a" }
    color_accent { "#c9a96e" }
    font_heading { "Playfair Display" }
    font_body { "Inter" }
    watermark_opacity { 0.3 }
  end
end
