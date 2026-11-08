require 'rails_helper'

# Endpoint contracts only: status codes, redirects and edge cases that are
# awkward or slow to prove through a browser. The diner's journey (join, see
# your place in line, return from another browser) is covered by Playwright
# in e2e/.
RSpec.describe "Parties", type: :request do
  let(:valid_params) { { party: { name: "Aiko Tanaka", email: "aiko@example.com", size: 2 } } }

  describe "POST /parties" do
    it "re-renders the form with 422 and creates nothing when the input is invalid" do
      expect {
        post parties_path, params: { party: { name: "", email: "nope", size: 0 } }
      }.not_to change(Party, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Please fix 3 fields below")
    end

    it "sends a duplicate email (any case, extra spaces) to the existing party" do
      post parties_path, params: valid_params
      existing = Party.first

      expect {
        post parties_path, params: { party: valid_params[:party].merge(email: " AIKO@example.com ") }
      }.not_to change(Party, :count)

      expect(response).to redirect_to(party_path(existing))
      expect(flash[:notice]).to eq("You're already on the list.")
    end

    it "returns 400 when the party params are missing" do
      post parties_path, params: {}

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /parties/:token" do
    it "responds 404 for an unknown token" do
      get party_path("nope")

      expect(response).to have_http_status(:not_found)
    end
  end
end
