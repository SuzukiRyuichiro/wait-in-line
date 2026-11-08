require 'rails_helper'

# The reset hook wipes the database. Only the e2e environment loads it, so in
# any other environment the path must fall through to the router and 404.
RSpec.describe "E2E reset", type: :request do
  it "is not reachable outside the e2e environment" do
    create(:party)

    post "/__e2e__/reset"

    expect(response).to have_http_status(:not_found)
    expect(Party.count).to eq(1)
  end
end
