require 'rails_helper'

RSpec.describe Party, type: :model do
  subject(:party) { build(:party) }

  it "has a valid factory" do
    expect(party).to be_valid
  end

  describe "defaults" do
    subject(:party) { Party.new }

    it "generates a url-safe token" do
      expect(party.token).to match(/\A[A-Za-z0-9_-]{22}\z/)
    end

    it "generates a different token per party" do
      expect(Party.new.token).not_to eq(party.token)
    end

    it "starts out waiting and active" do
      expect(party).to have_attributes(status: "waiting", active: true)
    end
  end

  describe "email normalization" do
    it "strips whitespace and downcases" do
      party.email = "  Ada@Example.COM "
      party.valid?

      expect(party.email).to eq("ada@example.com")
    end

    it "leaves a nil email nil" do
      party.email = nil
      party.valid?

      expect(party.email).to be_nil
    end
  end

  describe "active sync" do
    it "is active when waiting" do
      party.status = "waiting"
      party.active = false
      party.valid?

      expect(party.active).to be true
    end

    it "is active when ready" do
      party.status = "ready"
      party.active = false
      party.valid?

      expect(party.active).to be true
    end

    it "is active when seated" do
      party.status = "seated"
      party.active = false
      party.valid?

      expect(party.active).to be true
    end

    it "is not active when completed" do
      party.status = "completed"
      party.active = true
      party.valid?

      expect(party.active).to be false
    end

    it "is not active when no_show" do
      party.status = "no_show"
      party.active = true
      party.valid?

      expect(party.active).to be false
    end
  end

  describe "validations" do
    describe "name" do
      it "is required" do
        party.name = " "
        expect(party).not_to be_valid
        expect(party.errors[:name]).to include("can't be blank")
      end

      it "allows 100 characters" do
        party.name = "a" * 100
        expect(party).to be_valid
      end

      it "rejects more than 100 characters" do
        party.name = "a" * 101
        expect(party).not_to be_valid
        expect(party.errors[:name]).to be_present
      end
    end

    describe "email" do
      it "is required" do
        party.email = ""
        expect(party).not_to be_valid
        expect(party.errors[:email]).to include("can't be blank")
      end

      it "must look like an email" do
        party.email = "not-an-email"
        expect(party).not_to be_valid
        expect(party.errors[:email]).to include("is invalid")
      end

      it "must be unique among active parties (case-insensitively)" do
        create(:party, email: "ada@example.com")
        party.email = "ADA@example.com"

        expect(party).not_to be_valid
        expect(party.errors[:email]).to include("is already on the waitlist")
      end

      it "can be reused once the earlier party is no longer active" do
        create(:party, email: "ada@example.com", status: "completed")
        party.email = "ada@example.com"

        expect(party).to be_valid
      end

      it "skips the uniqueness check for an inactive party" do
        create(:party, email: "ada@example.com")
        party.email = "ada@example.com"
        party.status = "no_show"

        expect(party).to be_valid
      end
    end

    describe "size" do
      it "is valid within the range" do
        party.size = Restaurant::CAPACITY
        expect(party).to be_valid
      end

      it "is invalid outside the range" do
        party.size = Restaurant::CAPACITY + 1
        expect(party).not_to be_valid
        expect(party.errors[:size]).to include("must be 1–#{Restaurant::CAPACITY}.")
      end
    end

    describe "status" do
      it "rejects unknown statuses" do
        party.status = "active"
        expect(party).not_to be_valid
        expect(party.errors[:status]).to include("is not included in the list")
      end
    end

    it "requires a ticket number" do
      party.ticket_number = nil
      expect(party).not_to be_valid
      expect(party.errors[:ticket_number]).to include("can't be blank")
    end

    it "requires a restaurant" do
      party.restaurant = nil
      expect(party).not_to be_valid
      expect(party.errors[:restaurant]).to be_present
    end
  end

  describe "#to_param" do
    it "is the token, so URLs don't expose the id" do
      expect(party.to_param).to eq(party.token)
    end
  end

  describe "#parties_ahead / #position" do
    it "counts only waiting parties with a lower ticket at the same restaurant" do
      create(:party, ticket_number: 1)                       # ahead
      create(:party, ticket_number: 2, status: "ready")      # not waiting
      create(:party, ticket_number: 3, status: "completed")  # not waiting
      create(:party, ticket_number: 5)                       # behind
      other = Restaurant.create!(name: "Sukiya")
      create(:party, ticket_number: 1, restaurant: other)    # other restaurant

      me = create(:party, ticket_number: 4)

      expect(me.parties_ahead).to eq(1)
      expect(me.position).to eq(2)
    end

    it "is first in line when nobody is ahead" do
      me = create(:party, ticket_number: 1)

      expect(me.position).to eq(1)
    end
  end
end
