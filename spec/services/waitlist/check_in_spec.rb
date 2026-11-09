require "rails_helper"

RSpec.describe Waitlist::CheckIn do
  # rails_helper truncates the DB and creates the one restaurant (capacity 10).
  let(:restaurant) { Restaurant.current }
  let(:now) { Time.current.change(usec: 0) } # Mongo stores milliseconds
  let(:per_person) { Rails.configuration.x.waitlist.service_seconds_per_person }

  # A party the ticker has readied: seats reserved, waiting for the diner to tap.
  def ready_party(size: 4)
    party = create(:party, size: size)
    Waitlist::Settle.call(now: now)
    party.reload
  end

  def check_in(party, at: now)
    described_class.call(Party.find(party.id), now: at)
  end

  it "seats a ready party, occupies its seats and starts the service countdown" do
    party = ready_party(size: 4)

    result = check_in(party, at: now + 5.seconds)

    expect(result).to be_seated
    expect(party.reload).to have_attributes(status: "seated", active: true,
                                            seated_at: now + 5.seconds,
                                            service_ends_at: now + 5.seconds + 4 * per_person)
    expect(restaurant.reload).to have_attributes(seats_occupied: 4, seats_reserved: 4)
  end

  it "treats a second check-in as already seated and changes nothing" do
    party = ready_party(size: 4)
    check_in(party)

    result = check_in(party, at: now + 1.minute)

    expect(result).to be_already_seated
    expect(party.reload.seated_at).to eq(now)
    expect(restaurant.reload.seats_occupied).to eq(4)
  end

  it "refuses a party that isn't ready yet" do
    create(:party, ticket_number: 1, size: 10)
    Waitlist::Settle.call(now: now)
    waiting = create(:party, ticket_number: 2, size: 2)

    result = check_in(waiting)

    expect(result).to be_not_ready
    expect(waiting.reload).to be_waiting
    expect(restaurant.reload.seats_occupied).to eq(0)
  end

  it "seats the party once when several check-ins arrive at the same moment" do
    party = ready_party(size: 3)
    gate = Queue.new
    threads = Array.new(5) do
      Thread.new do
        gate.pop
        described_class.call(Party.find(party.id), now: now)
      end
    end
    5.times { gate << true }
    results = threads.map(&:value)

    expect(results.count(&:seated?)).to eq(1)
    expect(results.count(&:already_seated?)).to eq(4)
    expect(restaurant.reload.seats_occupied).to eq(3)
  end
end
