require "test_helper"

class AuthorizableTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:lazaro_nixon)
    @other = users(:two)
    @podcast = podcasts(:one)
    @podcast.update!(user: @owner)
    @episode = episodes(:one)
    @episode.update!(podcast: @podcast, status: :draft)
  end

  test "owner can access own podcast episodes" do
    sign_in_as(@owner)
    get podcast_episodes_url(@podcast)
    assert_response :success
  end

  test "non-owner redirected from another users podcast" do
    sign_in_as(@other)
    get podcast_episodes_url(@podcast)
    assert_redirected_to podcasts_url
  end

  test "non-owner redirected from another users episode" do
    sign_in_as(@other)
    get podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episodes_url(@podcast)
  end

  test "admin bypasses ownership checks" do
    @other.update!(role: :admin)
    sign_in_as(@other)
    get podcast_episode_url(@podcast, @episode)
    assert_response :success
  end

  test "regular user rejected from producer namespace" do
    sign_in_as(@owner)
    get producer_episodes_url
    assert_redirected_to root_url
  end
end
