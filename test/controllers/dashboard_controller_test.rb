require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index requires auth" do
    get dashboards_url
    assert_redirected_to sign_in_url
  end

  test "should get index when signed in" do
    sign_in_as users(:lazaro_nixon)
    get dashboards_url
    assert_response :success
  end
end
