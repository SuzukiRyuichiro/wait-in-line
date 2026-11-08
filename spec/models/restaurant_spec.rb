require 'rails_helper'

RSpec.describe Restaurant, type: :model do
  describe "defaults" do
    subject(:restaurant) { Restaurant.new }

    it "uses the fixed capacity and empty counters" do
      expect(restaurant).to have_attributes(
        capacity: Restaurant::CAPACITY,
        seats_reserved: 0,
        seats_occupied: 0,
        last_given_ticket_number: 0
      )
    end
  end

  describe ".current" do
    it "raises a helpful error when nothing is seeded" do
      Restaurant.delete_all

      expect { Restaurant.current }.to raise_error(/No restaurant found/)
    end
  end

  describe "#take_ticket!" do
    let(:restaurant) { Restaurant.current }

    it "returns sequential ticket numbers" do
      expect(3.times.map { restaurant.take_ticket! }).to eq([ 1, 2, 3 ])
    end

    it "persists the counter" do
      2.times { restaurant.take_ticket! }

      expect(restaurant.reload.last_given_ticket_number).to eq(2)
    end
  end

  describe "#parties" do
    it "lists the restaurant's parties" do
      party = create(:party, restaurant: Restaurant.current)

      expect(Restaurant.current.parties).to contain_exactly(party)
    end
  end
end
