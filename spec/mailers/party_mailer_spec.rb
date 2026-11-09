require "rails_helper"

RSpec.describe PartyMailer do
  it "tells the party their table is ready, with a link to their page" do
    party = create(:party, name: "Ada Lovelace", email: "ada@example.com", size: 3)

    mail = described_class.table_ready(party)

    expect(mail.to).to eq([ "ada@example.com" ])
    expect(mail.subject).to eq("Your table is ready, Ada")
    expect(mail.text_part.body.to_s).to include("Your table for 3 is ready")
    expect(mail.text_part.body.to_s).to include("/parties/#{party.token}")
    expect(mail.html_part.body.to_s).to include("/parties/#{party.token}")
  end
end
