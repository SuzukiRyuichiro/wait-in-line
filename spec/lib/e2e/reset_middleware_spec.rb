require 'rails_helper'
require Rails.root.join("lib/e2e/reset_middleware")

RSpec.describe E2E::ResetMiddleware do
  let(:app) { ->(_env) { [ 200, {}, [ "app" ] ] } }
  let(:middleware) { described_class.new(app) }

  it "empties the queue, re-seeds the restaurant and keeps the unique indexes" do
    create(:party)

    status, = middleware.call(Rack::MockRequest.env_for("/__e2e__/reset", method: "POST"))

    expect(status).to eq(204)
    expect(Party.count).to eq(0)
    expect(Restaurant.count).to eq(1)
    expect(Party.collection.indexes.map { |i| i["key"] }).to include({ "token" => 1 })
  end

  it "passes every other request through to the app" do
    status, _headers, body = middleware.call(Rack::MockRequest.env_for("/__e2e__/reset", method: "GET"))

    expect(status).to eq(200)
    expect(body).to eq([ "app" ])
  end
end
