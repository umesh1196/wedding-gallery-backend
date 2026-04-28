FactoryBot.define do
  factory :print_selection_bucket do
    association :wedding
    created_by_studio { wedding.studio }
    sequence(:name) { |n| "Print Album #{n}" }
    slug { nil }
    selection_limit { 20 }
    selected_count { 0 }
    sequence(:sort_order) { |n| n }
    locked_at { nil }
  end
end
