require "rails_helper"

RSpec.describe Waitlist::NotifyReady do
  # rails_helper truncates the DB and creates the one restaurant (capacity 10).
  let(:now) { Time.current.change(usec: 0) } # Mongo stores milliseconds

  def sent_to
    ActionMailer::Base.deliveries.map(&:to)
  end

  before { ActionMailer::Base.deliveries.clear }

  it "emails a ready party once and records when" do
    party = create(:party, email: "ada@example.com")
    Waitlist::Settle.call

    described_class.call(now: now)
    described_class.call(now: now + 1.second)

    expect(sent_to).to eq([ [ "ada@example.com" ] ])
    expect(party.reload.notified_at).to eq(now)
  end

  it "doesn't email parties that are still waiting" do
    create(:party, ticket_number: 1, size: 10, email: "big@example.com")
    create(:party, ticket_number: 2, size: 1, email: "small@example.com")
    Waitlist::Settle.call

    described_class.call

    expect(sent_to).to eq([ [ "big@example.com" ] ])
  end

  it "keeps the party ready and retries on the next tick when sending fails" do
    party = create(:party)
    Waitlist::Settle.call
    allow(PartyMailer).to receive(:table_ready).and_raise(Errno::ECONNREFUSED)

    described_class.call

    expect(party.reload).to have_attributes(status: "ready", notified_at: nil)

    allow(PartyMailer).to receive(:table_ready).and_call_original
    described_class.call(now: now)

    expect(party.reload.notified_at).to eq(now)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "still emails the other ready parties when one email fails" do
    create(:party, ticket_number: 1, size: 2, email: "bounce@example.com")
    create(:party, ticket_number: 2, size: 2, email: "ada@example.com")
    Waitlist::Settle.call
    allow(PartyMailer).to receive(:table_ready).and_wrap_original do |original, party|
      raise Errno::ECONNREFUSED if party.email == "bounce@example.com"

      original.call(party)
    end

    described_class.call

    expect(sent_to).to eq([ [ "ada@example.com" ] ])
  end
end
