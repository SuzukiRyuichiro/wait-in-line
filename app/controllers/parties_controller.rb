class PartiesController < ApplicationController
  def new
    return redirect_to(current_party, status: :see_other) if current_party&.active?

    @party = Party.new
    @waiting_count = Party.where(status: 'waiting').count
  end

  def create
    result = Waitlist::Join.call(party_params)

    if result.invalid?
      @party = result.party
      @waiting_count = Party.where(status: "waiting").count
      return render :new, status: :unprocessable_content
    end

    remember_party(result.party)
    notice = "You're already on the list." if result.duplicate?
    redirect_to result.party, notice:, status: :see_other
  end

  def show
    @party = Party.find_by(token: params[:token])
    remember_party(@party)
  end

  private

  def party_params
    params.expect(party: %i[name email size])
  end
end
