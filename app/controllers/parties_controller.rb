class PartiesController < ApplicationController
  def new
    redirect_to current_party, status: :see_other if current_party&.active?

    @party = Party.new
    @waiting_count = Party.where(status: 'waiting').count
  end

  def create
  end

  def show
  end

    def party_params
      params.expect(party: %i[name email size])
    end
end
