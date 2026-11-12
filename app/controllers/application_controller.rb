class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  private

  # Resolve the locale from the optional `:locale` URL segment (`/en`), falling
  # back to the default locale. The logged-in app has no locale prefix, so this
  # only affects public pages for now (i18n-plan Phase 4).
  def switch_locale(&action)
    I18n.with_locale(locale_from_params, &action)
  end

  def locale_from_params
    requested = params[:locale]
    if requested && I18n.available_locales.map(&:to_s).include?(requested)
      requested.to_sym
    else
      I18n.default_locale
    end
  end
end
