module Parties
  # GET /parties/:party_token/status.json, polled every few seconds by the
  # live-status island on the waiting and seated pages. Read-only: polling
  # never changes state (decision 1.12).
  class StatusesController < ApplicationController
    def show
      party = Party.find_by(token: params[:party_token]) # unknown token → 404
      response.headers["Cache-Control"] = "no-store"
      render json: party.live_state
    end
  end
end
