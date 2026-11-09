module Waitlist
  # Outbox for the "table ready" email (decision 1.13c, H4). Settle marks a
  # party ready with notified_at nil; this sends the email and then stamps
  # notified_at. If sending fails, or the process dies between the two, the next
  # tick sends again (at-least-once). The state change never depends on the
  # email: the party is ready whether or not the mail went out (E17).
  #
  # Only the ticker runs this. Two concurrent runs could send the same email
  # twice, so it must not also run from a web request.
  class NotifyReady
    def self.call(restaurant: Restaurant.current, now: Time.current)
      new(restaurant, now).call
    end

    def initialize(restaurant, now)
      @restaurant = restaurant
      @now = now
    end

    def call
      Party.where(restaurant_id: @restaurant.id, status: "ready", notified_at: nil).each do |party|
        notify(party)
      end
    end

    private

    def notify(party)
      # deliver_now blocks the tick while SMTP talks to Mailpit (1.13e). Fine at
      # this scale; deliver_later would need a job backend, which we don't have.
      PartyMailer.table_ready(party).deliver_now
      party.set(notified_at: @now)
    rescue StandardError => e
      # One bad address or an SMTP blip must not stop the other parties' emails.
      # notified_at stays nil, so the next tick retries this one.
      Rails.error.report(e, context: { party_id: party.id.to_s })
    end
  end
end
