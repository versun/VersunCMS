
require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    page = pages(:one)
    get page_url(page.slug)
    assert_response :success
  end

  test "should get new" do
    get new_page_url
    assert_response :success
  end

  test "should get edit" do
    page = pages(:one)
    get edit_page_url(page.slug)
    assert_response :success
  end
end
