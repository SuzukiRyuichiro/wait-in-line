FactoryBot.define do
  factory :party do
    token { "MyString" }
    ticket_number { 1 }
    name { "Scooter" }
    email { "mail@mail.com" }
    size { 1 }
    status { "active" }
    active { true }
  end
end
