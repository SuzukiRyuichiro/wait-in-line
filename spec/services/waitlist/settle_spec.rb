require "rails_helper"

RSpec.describe Waitlist::Settle do
  # rails_helper truncates the DB and creates the one restaurant (capacity 10).
  let(:restaurant) { Restaurant.current }
  let(:now) { Time.current.change(usec: 0) } # Mongo stores milliseconds

  def settle(at: now)
    described_class.call(restaurant: Restaurant.find(restaurant.id), now: at)
  end

  # Settle writes with its own queries, so always read the counter from the DB.
  def seats_reserved
    restaurant.reload.seats_reserved
  end

  def per_person
    Rails.configuration.x.waitlist.service_seconds_per_person
  end

  # Ready the party, then check it in at `now`: its service ends at
  # now + size × per_person.
  def seat(party)
    settle
    Waitlist::CheckIn.call(party.reload, now: now)
    party.reload
  end

  describe "readying the queue" do
    it "readies the head of the queue and reserves its seats" do
      party = create(:party, size: 4)

      settle

      expect(party.reload).to have_attributes(status: "ready", active: true, ready_at: now)
      expect(seats_reserved).to eq(4)
    end

    it "readies parties in ticket order while their seats fit" do
      first  = create(:party, ticket_number: 1, size: 4)
      second = create(:party, ticket_number: 2, size: 6)
      third  = create(:party, ticket_number: 3, size: 1)

      settle

      expect([ first, second, third ].map { |p| p.reload.status }).to eq(%w[ready ready waiting])
      expect(seats_reserved).to eq(10)
    end

    it "lets nobody skip ahead of a head that doesn't fit (strict FIFO)" do
      restaurant.set(seats_reserved: 7)
      big   = create(:party, ticket_number: 1, size: 4)
      small = create(:party, ticket_number: 2, size: 1)

      settle

      expect(big.reload).to be_waiting
      expect(small.reload).to be_waiting
      expect(seats_reserved).to eq(7)
    end

    it "does nothing when nobody is waiting" do
      expect { settle }.not_to(change { seats_reserved })
    end

    it "changes nothing when run again" do
      party = create(:party, size: 4)
      settle

      settle(at: now + 1.minute)

      expect(party.reload.ready_at).to eq(now)
      expect(seats_reserved).to eq(4)
    end

    it "keeps a ready party's seats however long it takes to check in" do
      party = create(:party, ticket_number: 1, size: 10)
      next_party = create(:party, ticket_number: 2, size: 1)
      settle

      settle(at: now + 1.day)

      expect(party.reload).to be_ready
      expect(next_party.reload).to be_waiting
      expect(seats_reserved).to eq(10)
    end
  end

  describe "finishing service" do
    it "keeps a seated party seated until its service time is up" do
      party = seat(create(:party, size: 4))

      settle(at: party.service_ends_at - 1.second)

      expect(party.reload).to be_seated
      expect(restaurant.reload).to have_attributes(seats_reserved: 4, seats_occupied: 4)
    end

    it "completes the party when its service ends and releases its seats" do
      party = seat(create(:party, size: 4))

      settle(at: now + 4 * per_person)

      expect(party.reload).to have_attributes(status: "completed", active: false,
                                              completed_at: now + 4 * per_person)
      expect(restaurant.reload).to have_attributes(seats_reserved: 0, seats_occupied: 0)
    end

    it "readies the next party with the freed seats in the same run" do
      seated = seat(create(:party, ticket_number: 1, size: 9))
      next_party = create(:party, ticket_number: 2, size: 2)
      settle
      expect(next_party.reload).to be_waiting

      settle(at: seated.service_ends_at)

      expect(next_party.reload).to be_ready
      expect(seats_reserved).to eq(2)
    end

    it "lets the diner join again with the same email once they're done" do
      seat(create(:party, email: "ada@example.com", size: 2))
      settle(at: now + 2 * per_person)

      result = Waitlist::Join.call({ name: "Ada", email: "ada@example.com", size: 2 })

      expect(result).to be_joined
    end
  end

  describe "running concurrently" do
    # The ticker and a join request can settle at the same moment (and in
    # production, two schedulers during a deploy). Seats must never be over-reserved.
    def settle_concurrently(times)
      gate = Queue.new
      threads = Array.new(times) do
        Thread.new do
          gate.pop
          described_class.call(restaurant: Restaurant.find(restaurant.id), now: now)
        end
      end
      times.times { gate << true }
      threads.each(&:join)
    end

    it "never reserves more seats than the restaurant has" do
      parties = Array.new(6) { |i| create(:party, ticket_number: i + 1, size: 3) }

      settle_concurrently(8)

      expect(parties.map { |p| p.reload.status }).to eq(%w[ready ready ready waiting waiting waiting])
      expect(seats_reserved).to eq(9)
    end

    it "completes a party and releases its seats exactly once" do
      party = seat(create(:party, size: 4))

      Array.new(5) { Thread.new { described_class.call(restaurant: Restaurant.find(restaurant.id), now: party.service_ends_at) } }.each(&:join)

      expect(party.reload).to be_completed
      expect(restaurant.reload).to have_attributes(seats_reserved: 0, seats_occupied: 0)
    end
  end
end
