# frozen_string_literal: true

# Public marketing page. Latvian is the eventual default at `/`; until the LV
# copy is supplied, `/` redirects to the English page at `/en`
# (see agents/docs/landing-page-plan.md).
class LandingController < ApplicationController
  layout "landing"
  allow_unauthenticated_access

  # Latvian is the eventual default at `/`; until the LV copy is supplied, `/`
  # redirects — signed-in users to their dashboard, guests to the English page.
  def show
    return if params[:locale].present?

    redirect_to(authenticated? ? dashboard_path : root_path(locale: :en), status: :found)
  end
end
