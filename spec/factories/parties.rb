FactoryBot.define do
  factory :party do
    # rails_helper seeds the single restaurant before every example
    restaurant { Restaurant.current }
    sequence(:ticket_number)
    name { "Scooter" }
    sequence(:email) { |n| "guest#{n}@example.com" }
    size { 2 }
    status { "waiting" }
  end
end
