require "rails_helper"

# Endpoint contracts only (decision 1.9): a crafted or stale POST, which a
# browser can't send from the UI. Checking in from the ready page is covered by
# Playwright in e2e/tests/check_in.spec.ts.
RSpec.describe "Check-ins", type: :request do
  describe "POST /parties/:party_token/check_in" do
    it "redirects a party that isn't ready back to its page and leaves it waiting" do
      create(:party, ticket_number: 1, size: 10)
      Waitlist::Settle.call
      waiting = create(:party, ticket_number: 2, size: 2)

      post party_check_in_path(waiting)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(party_path(waiting))
      expect(flash[:notice]).to eq("Your table isn't ready yet. We'll email you when it is.")
      expect(waiting.reload).to be_waiting
    end

    it "responds 404 for an unknown token" do
      post party_check_in_path("nope")

      expect(response).to have_http_status(:not_found)
    end
  end
end
