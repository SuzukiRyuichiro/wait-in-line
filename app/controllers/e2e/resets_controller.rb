# Test-only. The route is drawn only when E2E_RESET=1 (the isolated e2e stack),
# so this action is unreachable in dev and production.
module E2e
  class ResetsController < ApplicationController
    skip_forgery_protection

    def create
      # truncate! (not purge!) keeps the indexes, including the unique ones
      # that guarantee no duplicate active parties.
      Mongoid.truncate!
      Rails.application.load_seed
      head :no_content
    end
  end
end
