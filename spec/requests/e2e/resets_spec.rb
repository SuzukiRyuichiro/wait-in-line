require 'rails_helper'

# The reset endpoint wipes the database. It must only exist on the isolated
# e2e stack (E2E_RESET=1), never in a normal run.
RSpec.describe "E2E reset", type: :request do
  it "is not routable without E2E_RESET=1" do
    create(:party)

    post "/e2e/reset"

    expect(response).to have_http_status(:not_found)
    expect(Party.count).to eq(1)
  end
end
