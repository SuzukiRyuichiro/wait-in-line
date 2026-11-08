class Restaurant
  include Mongoid::Document
  include Mongoid::Timestamps

  CAPACITY = 10 # Required by the take home test

  field :name, type: String
  field :capacity, type: Integer, default: CAPACITY
  field :seats_reserved, type: Integer, default: 0
  field :seats_occupied, type: Integer, default: 0
  field :next_ticket_number, type: Integer, default: 0

  has_many :parties

  # based on the assignment requirement, I assumed the app
  # only have one restaurant, so the code is written expecting
  # the app have been seeded with just one restaurant
  def self.current
    first || raise("No restaurant found. Run `bin/rails db:seed`")
  end

  def take_ticket!
    Restaurant.where(_id: id)
              .find_one_and_update({ "$inc" => { next_ticket_number: 1 } }, return_document: :after)
              .next_ticket_number
  end
end
