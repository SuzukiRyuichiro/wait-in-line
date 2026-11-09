class PartyMailer < ApplicationMailer
  # Sent by Waitlist::NotifyReady once the party's seats are reserved (H4).
  def table_ready(party)
    @party = party
    mail to: party.email, subject: "Your table is ready, #{party.name.split.first}"
  end
end
