module CurrentParty
  extend ActiveSupport::Concern
  COOKIE = :party_token

  included { helper_method :current_party }

  private

  # The party this browser remembers, or nil.
  def current_party
    return @current_party if defined?(@current_party)
    token = cookies.signed[COOKIE]
    @current_party = token.present? ? Party.where(token: token).first : nil
  end

  def remember_party(party)
    cookies.signed.permanent[COOKIE] = { value: party.token, httponly: true, same_site: :lax }
    @current_party = party
  end
end
