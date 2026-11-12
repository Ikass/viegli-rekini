# frozen_string_literal: true

# Public marketing page. Latvian is the default public language at `/`;
# English lives at `/en`. Copy is in config/locales/landing.{lv,en}.yml.
class LandingController < ApplicationController
  layout "landing"
  allow_unauthenticated_access

  def show
  end

  private

  # `/` is the Latvian page (the product's default public language); `/en` is
  # English. The logged-in app has no locale prefix and keeps `default_locale`.
  def locale_from_params
    requested = params[:locale]
    if requested && I18n.available_locales.map(&:to_s).include?(requested)
      requested.to_sym
    else
      :lv
    end
  end
end
