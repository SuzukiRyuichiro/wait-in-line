module Parties
  # POST /parties/:party_token/check_in, from the "Check in" button on the
  # ready page. A plain form post, so it works without JS (E12).
  class CheckInsController < ApplicationController
    def create
      party = Party.find_by(token: params[:party_token]) # unknown token → 404
      result = Waitlist::CheckIn.call(party)

      # A double tap is not an error (E8): the second request just lands on the
      # seated page. A party that isn't ready (stale tab, crafted POST) is sent
      # back to its real state (E7).
      notice = "Your table isn't ready yet. We'll email you when it is." if result.not_ready?
      redirect_to result.party, notice:, status: :see_other
    end
  end
end
