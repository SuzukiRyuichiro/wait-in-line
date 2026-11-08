require "rails_helper"

RSpec.describe Waitlist::Join do
  # rails_helper truncates the DB and creates the one restaurant before every
  # example, so the ticket counter always starts at 0.
  let(:restaurant) { Restaurant.current }
  let(:valid_params) { { name: "Ada", email: "ada@example.com", size: 2 } }

  def join(params = valid_params)
    described_class.call(params, restaurant: restaurant)
  end

  # take_ticket! writes with its own query, so always read the counter from the DB.
  def counter
    restaurant.reload.last_given_ticket_number
  end

  describe "happy path" do
    it "creates a waiting party with the first ticket" do
      result = join

      expect(result).to be_joined
      expect(result.party.reload).to have_attributes(
        name: "Ada", email: "ada@example.com", size: 2,
        status: "waiting", active: true, ticket_number: 1, restaurant_id: restaurant.id
      )
      expect(counter).to eq(1)
    end

    it "gives each new party the next ticket" do
      tickets = %w[a b c].map { |n| join(valid_params.merge(email: "#{n}@x.com")).party.ticket_number }

      expect(tickets).to eq([ 1, 2, 3 ])
    end

    it "normalizes the email" do
      expect(join(valid_params.merge(email: "  Ada@Example.COM ")).party.email).to eq("ada@example.com")
    end

    it "accepts permitted controller params" do
      params = ActionController::Parameters
               .new(party: { name: "Ada", email: "ada@example.com", size: "4" })
               .require(:party).permit(:name, :email, :size)

      expect(join(params).party.size).to eq(4)
    end

    it "accepts the maximum party size of 10" do
      result = join(valid_params.merge(size: 10))

      expect(result).to be_joined
      expect(result.party.reload.size).to eq(10)
    end

    it "ignores fields the diner shouldn't set" do
      party = join(valid_params.merge(status: "seated", token: "chosen", ticket_number: 99)).party.reload

      expect(party).to have_attributes(status: "waiting", ticket_number: 1)
      expect(party.token).not_to eq("chosen")
    end
  end

  describe "invalid input" do
    it "rejects a blank name without saving or using a ticket" do
      result = join(valid_params.merge(name: ""))

      expect(result).to be_invalid
      expect(result.party.errors[:name]).to be_present
      expect(Party.count).to eq(0)
      expect(counter).to eq(0)
    end

    it "rejects a malformed email without saving or using a ticket" do
      result = join(valid_params.merge(email: "nope"))

      expect(result).to be_invalid
      expect(result.party.errors[:email]).to be_present
      expect(Party.count).to eq(0)
      expect(counter).to eq(0)
    end

    it "rejects a party size below the minimum without saving or using a ticket" do
      result = join(valid_params.merge(size: 0))

      expect(result).to be_invalid
      expect(result.party.errors[:size]).to be_present
      expect(Party.count).to eq(0)
      expect(counter).to eq(0)
    end

    it "rejects a party size above the maximum without saving or using a ticket" do
      result = join(valid_params.merge(size: 11))

      expect(result).to be_invalid
      expect(result.party.errors[:size]).to be_present
      expect(Party.count).to eq(0)
      expect(counter).to eq(0)
    end

    it "rejects a party size that isn't a number without saving or using a ticket" do
      result = join(valid_params.merge(size: "abc"))

      expect(result).to be_invalid
      expect(result.party.errors[:size]).to be_present
      expect(Party.count).to eq(0)
      expect(counter).to eq(0)
    end

    it "rejects a missing party size without saving or using a ticket" do
      result = join(valid_params.merge(size: nil))

      expect(result).to be_invalid
      expect(result.party.errors[:size]).to be_present
      expect(Party.count).to eq(0)
      expect(counter).to eq(0)
    end

    it "leaves no gap in ticket numbers after a failed attempt" do
      join(valid_params.merge(email: "a@x.com"))
      join(valid_params.merge(email: "b@x.com", size: 0))

      expect(join(valid_params.merge(email: "c@x.com")).party.ticket_number).to eq(2)
    end
  end

  # Resubmitting (refresh, back button, double-click, joining from another
  # device) must not create a second party or use another ticket.
  describe "joining again with the same email (idempotency)" do
    let!(:existing) { join.party }

    it "returns the existing party instead of creating a new one" do
      result = join(valid_params.merge(name: "Someone else", size: 5))

      expect(result).to be_duplicate
      expect(result.party).to eq(existing)
      expect(existing.reload).to have_attributes(name: "Ada", size: 2)
      expect(Party.count).to eq(1)
      expect(counter).to eq(1)
    end

    it "matches regardless of case and surrounding spaces" do
      expect(join(valid_params.merge(email: " ADA@example.com "))).to be_duplicate
    end

    it "sends the diner to their party even if the resubmitted form has errors" do
      expect(join(valid_params.merge(size: 0)).party).to eq(existing)
    end

    it "still counts as a duplicate once the party has been called" do
      existing.update!(status: "ready")

      expect(join).to be_duplicate
    end

    it "still counts as a duplicate while the party is seated" do
      existing.update!(status: "seated")

      expect(join).to be_duplicate
    end

    it "lets the diner join again once their old party has finished dining" do
      existing.update!(status: "completed")

      result = join

      expect(result).to be_joined
      expect(result.party).not_to eq(existing)
      expect(result.party.ticket_number).to eq(2)
    end

    it "lets the diner join again after their old party was marked a no-show" do
      existing.update!(status: "no_show")

      result = join

      expect(result).to be_joined
      expect(result.party).not_to eq(existing)
      expect(result.party.ticket_number).to eq(2)
    end

    it "returns :invalid (not the old party) for bad input after the old party finished" do
      existing.update!(status: "completed")

      result = join(valid_params.merge(name: ""))

      expect(result).to be_invalid
      expect(result.party).to be_new_record
    end
  end

  # Requests that arrive at the same moment: a double-tapped submit button,
  # or a busy evening with many diners joining at once.
  describe "concurrent joins" do
    def join_concurrently(params_list)
      gate = Queue.new
      threads = params_list.map do |params|
        Thread.new do
          gate.pop # wait so all threads start together
          described_class.call(params, restaurant: Restaurant.find(restaurant.id))
        end
      end
      params_list.size.times { gate << true }
      threads.map(&:value)
    end

    it "creates exactly one party when the same diner submits many times at once" do
      results = join_concurrently(Array.new(10) { valid_params })

      expect(results.map(&:status).tally).to eq(joined: 1, duplicate: 9)
      expect(results.map { |r| r.party.id }.uniq.size).to eq(1)
      expect(Party.count).to eq(1)
      expect(counter).to eq(1)
    end

    it "gives different diners unique tickets with no gaps" do
      results = join_concurrently(Array.new(10) { |i| valid_params.merge(email: "d#{i}@x.com") })

      expect(results).to all(be_joined)
      expect(Party.pluck(:ticket_number).sort).to eq((1..10).to_a)
      expect(counter).to eq(10)
    end

    # The unique index is the last line of defence if two requests ever both
    # pass the uniqueness validation. Turning the validator off forces that.
    it "falls back to the unique email index if validation is bypassed" do
      existing = join.party
      allow_any_instance_of(Mongoid::Validatable::UniquenessValidator).to receive(:validate_each)

      result = join

      expect(result).to be_duplicate
      expect(result.party).to eq(existing)
      expect(Party.count).to eq(1)
      expect(counter).to eq(1)
    end
  end

  describe "unexpected database errors" do
    it "re-raises them and rolls back the ticket" do
      allow_any_instance_of(Party).to receive(:save!)
        .and_raise(Mongo::Error::OperationFailure.new("boom", nil, code: 50))

      expect { join }.to raise_error(Mongo::Error::OperationFailure)
      expect(Party.count).to eq(0)
      expect(counter).to eq(0)
    end
  end
end
