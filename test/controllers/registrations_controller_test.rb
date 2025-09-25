require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "should get new" do
    get sign_up_url
    assert_response :success
  end

  test "should sign up" do
    assert_enqueued_emails 1 do
      assert_difference("User.count", 1) do
        assert_difference("Session.count", 1) do
          post sign_up_url, params: { email: "lazaronixon@hey.com", password: "Secret1*3*5*", password_confirmation: "Secret1*3*5*" }
        end
      end
    end

    assert_redirected_to root_url

    # Follow to final landing page after root redirect
    follow_redirect!
    follow_redirect!
    assert_response :success

    user = User.find_by(email: "lazaronixon@hey.com")
    assert_not_nil user
    assert_equal 1, user.sessions.count
  end

  test "should not sign up with password mismatch" do
    assert_no_difference([ "User.count", "Session.count" ]) do
      post sign_up_url, params: { email: "mismatch@example.com", password: "Secret1*3*5*", password_confirmation: "Different1*3*5*" }
    end

    assert_response :unprocessable_entity
  end

  test "should not sign up with duplicate email" do
    existing = users(:lazaro_nixon)

    assert_no_difference([ "User.count", "Session.count" ]) do
      post sign_up_url, params: { email: existing.email, password: "Secret1*3*5*", password_confirmation: "Secret1*3*5*" }
    end

    assert_response :unprocessable_entity
  end
end
