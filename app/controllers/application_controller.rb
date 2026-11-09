class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  include CurrentParty

  # An unknown or mistyped party link (E9): a page in the app's own layout that
  # points back to the join form, instead of the bare static 404. The status
  # JSON (and any other format) just gets the status code.
  rescue_from Mongoid::Errors::DocumentNotFound do
    respond_to do |format|
      format.html { render "parties/not_found", status: :not_found }
      format.any  { head :not_found }
    end
  end
end
