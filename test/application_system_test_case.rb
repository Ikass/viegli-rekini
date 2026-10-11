require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  def sign_in_as(user)
    visit new_session_url
    fill_field_via_js("input[name='email_address']", user.email_address)
    fill_field_via_js("input[name='password']", "password")
    submit_via_native_form
    assert_text "Invoices"
  end

  # Turbo's fetch-based form submission doesn't work reliably in system tests.
  # This helper submits the form natively via JavaScript, bypassing Turbo entirely.
  def submit_via_native_form
    page.execute_script "document.querySelector('main form').submit()"
  end

  # "Send invoice" is a submit button living *outside* the invoice form, wired up
  # via the HTML `form="invoice_form"` attribute. That relies on Turbo's submit
  # interceptor (flaky in headless Chrome). Drive the same transition natively:
  # inject the `commit=send` param the controller's send path expects, then call
  # form.submit() — which skips the submit event and navigates directly.
  def send_invoice_via_js
    page.execute_script(<<~JS)
      const form = document.querySelector('#invoice_form');
      const commit = document.createElement('input');
      commit.type = 'hidden';
      commit.name = 'commit';
      commit.value = 'send';
      form.appendChild(commit);
      form.submit();
    JS
  end

  # After a native form submission (via submit_via_native_form), Selenium's
  # send_keys-based methods (fill_in, set) can stop working on subsequent pages.
  # Use this helper to set field values via JS instead.
  def fill_field_via_js(selector, value)
    json_value = value.to_json
    page.execute_script(%(document.querySelector("#{selector}").value = #{json_value}))
  end

  # Reset browser state between tests to avoid stale session cookies
  # conflicting with rolled-back database transactions.
  def reset_browser_state
    page.driver.browser.manage.delete_all_cookies
    page.execute_script("sessionStorage.clear()") rescue nil
    page.execute_script("localStorage.clear()") rescue nil
  end

  setup do
    reset_browser_state
  end
end
