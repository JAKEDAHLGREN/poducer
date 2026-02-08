require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # === Email Normalization ===

  test "strips whitespace from email" do
    user = User.new(email: "  TEST@EXAMPLE.COM  ", password: "Secret1*3*5*")
    user.valid?
    assert_equal "test@example.com", user.email
  end

  test "downcases email" do
    user = User.new(email: "TEST@EXAMPLE.COM", password: "Secret1*3*5*")
    user.valid?
    assert_equal "test@example.com", user.email
  end

  # === Email Validation ===

  test "requires email" do
    user = User.new(email: nil, password: "Secret1*3*5*")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "enforces email uniqueness case-insensitively" do
    duplicate = User.new(email: @user.email.upcase, password: "Secret1*3*5*")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  # === Role Enum ===

  test "defaults to user role" do
    user = User.new(email: "new@example.com", password: "Secret1*3*5*")
    assert user.user?
  end

  test "includes user, producer, and admin roles" do
    assert_equal({ "user" => 0, "producer" => 1, "admin" => 2 }, User.roles)
  end

  # === Token Generation ===

  test "generate_token_for returns a string" do
    token = @user.generate_token_for(:email_verification)
    assert_instance_of String, token
    assert token.length > 0
  end

  test "find_by_token_for resolves token back to user" do
    token = @user.generate_token_for(:email_verification)
    found = User.find_by_token_for!(:email_verification, token)
    assert_equal @user, found
  end

  test "find_by_token_for raises on invalid token" do
    assert_raises(StandardError) do
      User.find_by_token_for!(:email_verification, "invalid-token")
    end
  end

  # === Associations ===

  test "has many podcasts and sessions" do
    assert_respond_to @user, :podcasts
    assert_respond_to @user, :sessions
    assert_equal :destroy, User.reflect_on_association(:podcasts).options[:dependent]
    assert_equal :destroy, User.reflect_on_association(:sessions).options[:dependent]
  end
end
