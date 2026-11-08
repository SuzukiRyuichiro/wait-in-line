FactoryBot.define do
  factory :restaurant do
    name { "MyString" }
    slug { "MyString" }
    capacity { 1 }
    seats_reserved { 1 }
    seats_occupied { 1 }
    next_ticket_number { 1 }
  end
end
