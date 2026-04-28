FactoryBot.define do
  factory :print_selection_photo do
    association :print_selection_bucket
    association :photo
  end
end
