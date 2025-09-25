require "test_helper"

class Identity::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should get edit" do
    get edit_identity_email_url
    assert_response :success
  end

  test "should update email" do
    assert_enqueued_email_with UserMailer, :email_verification, params: { user: @user } do
      patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: "Secret1*3*5*" }
    end
    assert_redirected_to root_url
    assert_equal "Your email has been changed", flash[:notice]
  end


  test "should not update email with wrong password challenge" do
    patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: "SecretWrong1*3" }

    assert_response :unprocessable_entity
    assert_select "li", /Password challenge is invalid/
  end

  test "should not enqueue email when email unchanged" do
    user = users(:lazaro_nixon)
    assert_no_enqueued_emails do
      patch identity_email_url, params: { email: user.email, password_challenge: "Secret1*3*5*" }
    end
    assert_redirected_to root_url
  end
end
