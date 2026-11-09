require "rails_helper"

# The JSON contract the live-status island relies on. The page updating by
# itself is covered by Playwright in e2e/tests/live_status.spec.ts.
RSpec.describe "Party status", type: :request do
  describe "GET /parties/:party_token/status.json" do
    it "returns a waiting party's status and place in line, never cached" do
      create(:party, ticket_number: 1, size: 10)
      Waitlist::Settle.call
      waiting = create(:party, ticket_number: 2, size: 2)

      get party_status_path(waiting, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("status" => "waiting", "position" => 1)
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "returns no position once the party has left the line" do
      party = create(:party)
      Waitlist::Settle.call

      get party_status_path(party, format: :json)

      expect(response.parsed_body).to eq("status" => "ready", "position" => nil)
    end

    it "responds 404 for an unknown token" do
      get party_status_path("nope", format: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end
