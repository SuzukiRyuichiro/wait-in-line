module Waitlist
  # The time-driven half of the state machine (decision 1.12). The ticker calls
  # it every tick; PartiesController#create also calls it right after a join so a
  # diner who walks into an empty restaurant is ready at once (H10).
  #
  # Safe to run late, twice, or concurrently: every step is a conditional update
  # inside a transaction, and every step that changes state writes the Restaurant
  # document, so two overlapping runs conflict on it and MongoDB retries one of them.
  class Settle
    def self.call(restaurant: Restaurant.current, now: Time.current)
      new(restaurant, now).call
    end

    def initialize(restaurant, now)
      @restaurant = restaurant
      @now = now
    end

    def call
      ready_parties
    end

    private

    # Strict FIFO (A7): ready the head of the queue while its seats fit.
    # One tick can ready several parties (e.g. three parties of 3 into an empty
    # restaurant), so loop until the head doesn't fit or the queue is empty.
    def ready_parties
      loop do
        # One small transaction per party: a conflict only retries this step.
        readied = Mongoid.transaction { ready_head_of_queue }
        break unless readied
      end
    end

    # Returns the party it readied, or nil if the queue is empty or the head
    # doesn't fit yet (nobody behind it skips ahead).
    #
    # Mongoid.transaction retries the whole block on a write conflict, so the
    # head is read inside it: a retry sees what the winning run already did.
    def ready_head_of_queue
      head = Party.where(restaurant_id: @restaurant.id, status: "waiting").order_by(ticket_number: :asc).first
      return nil unless head

      # Reserve the seats only if they fit. The filter is the capacity guard, so
      # this single atomic update can never push the count past capacity.
      # A ready party keeps its seats until it checks in (no deadline, see A8).
      reserved = Restaurant.where(_id: @restaurant.id, :seats_reserved.lte => @restaurant.capacity - head.size)
                           .find_one_and_update({ "$inc" => { seats_reserved: head.size } })
      return nil unless reserved

      # Can't fail in practice: another run readying `head` would have written
      # the restaurant first and made our $inc conflict. The raise rolls the
      # $inc back if a future code path ever changes a status without it.
      Party.where(_id: head.id, status: "waiting").find_one_and_update(
        { "$set" => { status: "ready", ready_at: @now } },
        return_document: :after
      ) || raise("party #{head.id} left 'waiting' mid-transaction")
    end
  end
end
