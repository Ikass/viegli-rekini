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

  test "declares hreflang alternates and a canonical for each locale" do
    get "/"

    assert_select 'link[rel="canonical"][href="http://www.example.com/"]', 1
    assert_select 'link[rel="alternate"][hreflang="lv"][href="http://www.example.com/"]', 1
    assert_select 'link[rel="alternate"][hreflang="en"][href="http://www.example.com/en"]', 1
    assert_select 'link[rel="alternate"][hreflang="x-default"][href="http://www.example.com/"]', 1

    get "/en"

    assert_select 'link[rel="canonical"][href="http://www.example.com/en"]', 1
    assert_select 'link[rel="alternate"][hreflang="lv"][href="http://www.example.com/"]', 1
    assert_select 'link[rel="alternate"][hreflang="en"][href="http://www.example.com/en"]', 1
    assert_select 'link[rel="alternate"][hreflang="x-default"][href="http://www.example.com/"]', 1
  end

  test "links to the other language" do
    get "/"

    assert_select "nav a.landing-lang[hreflang=en][href='/en']" do
      assert_select ".landing-lang-code", text: "EN"
    end

    get "/en"

    assert_select "nav a.landing-lang[hreflang=lv][href='/']" do
      assert_select ".landing-lang-code", text: "LV"
    end
  end

  test "does not require authentication" do
    get "/en"

    assert_response :success
  end
end
