FactoryBot.define do
  factory :restaurant do
    name { "Yoshinoya" }
    capacity { 1 }
    seats_reserved { 1 }
    seats_occupied { 1 }
    last_given_ticket_number { 0 }
  end
end
