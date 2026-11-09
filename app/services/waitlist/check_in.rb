module Waitlist
  # ready → seated, when the diner taps "Check in" (H5). The human-initiated
  # half of the state machine (decision 1.12); the ticker never does this.
  #
  # Per the spec, checking in removes the party from the queue, decreases the
  # seats available by the party size, and starts the service countdown.
  # The seats were already *reserved* when the party became ready (Settle), so
  # here they become *occupied*: seats_occupied is what "seats available" means
  # to a diner (capacity - seats_occupied).
  class CheckIn
    Result = Data.define(:status, :party) do
      def seated?         = status == :seated
      def already_seated? = status == :already_seated
      def not_ready?      = status == :not_ready
    end

    def self.call(party, now: Time.current)
      new(party, now).call
    end

    def initialize(party, now)
      @party = party
      @now = now
    end

    def call
      seated = Mongoid.transaction { seat }
      return Result.new(:seated, seated) if seated

      # Nothing changed. Tell the caller why, from the party's current state.
      party = @party.reload
      Result.new(party.seated? ? :already_seated : :not_ready, party)
    end

    private

    # Returns the seated party, or nil if it wasn't ready.
    #
    # The conditional update is the guard: only a party that is still `ready`
    # gets seated, so a double tap or two tabs checking in at once seat it once.
    # Concurrent check-ins write the same party document, so one transaction
    # hits a write conflict, is retried, and then finds the party already seated.
    def seat
      seated = Party.where(_id: @party.id, status: "ready").find_one_and_update(
        { "$set" => { status: "seated", seated_at: @now, service_ends_at: @now + service_time } },
        return_document: :after
      )
      return nil unless seated

      Restaurant.where(_id: seated.restaurant_id).find_one_and_update({ "$inc" => { seats_occupied: seated.size } })
      seated
    end

    def service_time
      @party.size * Rails.configuration.x.waitlist.service_seconds_per_person
    end
  end
end
