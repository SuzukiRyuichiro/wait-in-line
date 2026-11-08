module Waitlist
  class Join
    # This result data transfer object will be useful to know the
    # end result of the join action from the controller
    Result = Data.define(:status, :party) do
      def joined?
        status == :joined
      end

      def duplicate?
        status == :duplicate
      end

      def invalid?
        status == :invalid
      end
    end

    # Mongo's error code for "E11000 duplicate key" (a unique index rejected the insert)
    DUPLICATE_KEY = 11000

    # To reduce the extra of instantiating the service obj when .call
    def self.call(params, restaurant: Restaurant.current)
      new(params, restaurant).call
    end

    def initialize(params, restaurant)
      @params = params
      @restaurant = restaurant
    end

    def call
      party = nil

      Mongoid.transaction do
        party = @restaurant.parties.new(@params)
        party.ticket_number = @restaurant.take_ticket!
        party.save!
      end

      Result.new(:joined, party)
    rescue Mongoid::Errors::Validations => e
      # Layer 1: our Ruby validations failed. Nothing was inserted.
      handle_validation_failure(e.document)
    rescue Mongo::Error::OperationFailure => e
      # Layer 2: the DB itself rejected the insert.
      handle_database_failure(e, party)
    end

    private

    # Validations failed (blank name, bad email, email already on the list, ...).
    # The transaction rolled back, so the ticket number was NOT consumed.
    def handle_validation_failure(party)
      # ticket_number is internal, not something the diner can fix in the form
      party.errors.delete(:ticket_number)
      existing = find_active_party(party.email)

      if existing
        # This email is already on the list: send them to their existing party
        Result.new(:duplicate, existing)
      else
        # Genuinely invalid input: re-render the form with errors
        Result.new(:invalid, party)
      end
    end

    # The DB rejected the insert. The only case we expect is losing a race:
    # two identical joins both passed validation, and the unique email index
    # rejected the second one.
    def handle_database_failure(error, party)
      # Some other DB problem (timeout, auth, ...): not ours to handle
      # Defensive: the failure happened before the party was even built
      raise error if error.code != DUPLICATE_KEY || party.nil?

      existing = find_active_party(party.email)

      if existing.nil?
        # Duplicate key, but not on email (token or ticket_number collision).
        # That's a bug, not user error, so let it surface.
        raise error
      end

      Result.new(:duplicate, existing)
    end

    def find_active_party(email)
      Party.where(email: email, active: true).first
    end
  end
end
