# frozen_string_literal: true

require "test_helper"

class LandingControllerTest < ActionDispatch::IntegrationTest
  test "renders the Latvian landing at /" do
    get "/"

    assert_response :success
    assert_select "html[lang=lv]"
    assert_select "h1", text: /Rēķins trīs soļos/
  end

  test "renders the English landing at /en" do
    get "/en"

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "h1", text: /Invoices in three steps/
  end

  test "declares hreflang alternates and a canonical" do
    get "/"

    assert_select 'link[rel="alternate"][hreflang="lv"]', 1
    assert_select 'link[rel="alternate"][hreflang="en"]', 1
    assert_select 'link[rel="alternate"][hreflang="x-default"]', 1
    assert_select 'link[rel="canonical"]', 1
  end

  test "links to the other language" do
    get "/"

    assert_select "nav a[hreflang=en]", text: "English"

    get "/en"

    assert_select "nav a[hreflang=lv]", text: "Latviešu"
  end

  test "does not require authentication" do
    get "/en"

    assert_response :success
  end
end
