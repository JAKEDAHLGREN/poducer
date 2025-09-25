require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should get edit" do
    get edit_password_url
    assert_response :success
  end

  test "should update password" do
    patch password_url, params: { password_challenge: "Secret1*3*5*", password: "Secret6*4*2*", password_confirmation: "Secret6*4*2*" }
    assert_redirected_to root_url
  end

  test "should not update password with wrong password challenge" do
    patch password_url, params: { password_challenge: "SecretWrong1*3", password: "Secret6*4*2*", password_confirmation: "Secret6*4*2*" }

    assert_response :unprocessable_entity
    assert_select "li", /Password challenge is invalid/
  end

  test "should not update password when confirmation mismatch" do
    patch password_url, params: { password_challenge: "Secret1*3*5*", password: "Secret6*4*2*", password_confirmation: "Mismatch6*4*2*" }

    assert_response :unprocessable_entity
    assert_select "li", /Password confirmation doesn't match Password/
  end

  test "should require password challenge presence" do
    patch password_url, params: { password: "Secret6*4*2*", password_confirmation: "Secret6*4*2*" }

    assert_response :unprocessable_entity
    assert_select "li", /Password challenge is invalid|
                          Password challenge can't be blank/
  end

  test "can sign in with new password after change" do
    patch password_url, params: { password_challenge: "Secret1*3*5*", password: "NewSecret9*8*7*", password_confirmation: "NewSecret9*8*7*" }
    assert_redirected_to root_url

    delete sign_out_url

    post sign_in_url, params: { email: users(:lazaro_nixon).email, password: "NewSecret9*8*7*" }
    assert_redirected_to root_url
  end
end
